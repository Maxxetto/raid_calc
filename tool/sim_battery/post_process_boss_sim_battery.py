import csv
import heapq
import math
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Dict, Iterable, Iterator, List, Tuple


SCENARIO_RE = re.compile(
    r'^(?P<mode>[a-z]+)-l(?P<boss_level>\d+)'
    r'-layout_(?P<layout>[a-z]+)'
    r'-kadv_(?P<kadv>[0-9_]+-[0-9_]+-[0-9_]+)'
    r'-badv_(?P<badv>[0-9_]+-[0-9_]+-[0-9_]+)'
    r'-pet_(?P<pet>.+)'
    r'-skill_(?P<skill>.+)'
    r'-tier_(?P<tier>tier_\d+)'
    r'-(?P<variant>normal|swapped)$'
)


class RunningStats:
    __slots__ = ('count', 'sum', 'sumsq', 'min', 'max')

    def __init__(self) -> None:
        self.count = 0
        self.sum = 0.0
        self.sumsq = 0.0
        self.min = math.inf
        self.max = -math.inf

    def add(self, value: float) -> None:
        self.count += 1
        self.sum += value
        self.sumsq += value * value
        if value < self.min:
            self.min = value
        if value > self.max:
            self.max = value

    @property
    def mean(self) -> float:
        if self.count == 0:
            return 0.0
        return self.sum / self.count

    @property
    def variance(self) -> float:
        if self.count <= 0:
            return 0.0
        raw = (self.sumsq / self.count) - (self.mean * self.mean)
        return raw if raw > 0 else 0.0

    @property
    def stddev(self) -> float:
        return math.sqrt(self.variance)


class RateStats(RunningStats):
    __slots__ = ()


@dataclass
class GroupSummary:
    count: int = 0
    score: RunningStats = field(default_factory=RunningStats)
    damage: RunningStats = field(default_factory=RunningStats)
    damage_stddev: RunningStats = field(default_factory=RunningStats)
    completion: RateStats = field(default_factory=RateStats)
    survival: RateStats = field(default_factory=RateStats)
    turns: RunningStats = field(default_factory=RunningStats)
    pet_casts: RunningStats = field(default_factory=RunningStats)

    def add(
        self,
        final_score: float,
        mean_damage: float,
        damage_stddev: float,
        completion_rate: float,
        survival_rate: float,
        mean_turns: float,
        mean_pet_casts: float,
    ) -> None:
        self.count += 1
        self.score.add(final_score)
        self.damage.add(mean_damage)
        self.damage_stddev.add(damage_stddev)
        self.completion.add(completion_rate)
        self.survival.add(survival_rate)
        self.turns.add(mean_turns)
        self.pet_casts.add(mean_pet_casts)


@dataclass
class PairComparison:
    count: int = 0
    uplift: RunningStats = field(default_factory=RunningStats)
    positive_count: int = 0

    def add(self, value: float) -> None:
        self.count += 1
        self.uplift.add(value)
        if value > 0:
            self.positive_count += 1

    @property
    def positive_rate(self) -> float:
        if self.count == 0:
            return 0.0
        return self.positive_count / self.count


def parse_scenario_id(scenario_id: str) -> Dict[str, object]:
    match = SCENARIO_RE.match(scenario_id)
    if not match:
        raise ValueError(f'Unable to parse scenario id: {scenario_id}')
    layout = match.group('layout')
    knight_adv = parse_vector(match.group('kadv'))
    boss_adv = parse_vector(match.group('badv'))
    primary_slot = layout.index('p') + 1
    return {
        'mode': match.group('mode'),
        'boss_level': int(match.group('boss_level')),
        'layout': layout,
        'primary_slot': primary_slot,
        'knight_adv_vector': match.group('kadv'),
        'boss_adv_vector': match.group('badv'),
        'knight_adv_mean': sum(knight_adv) / len(knight_adv),
        'boss_adv_mean': sum(boss_adv) / len(boss_adv),
        'pet_strategy': match.group('pet'),
        'pet_primary_skill': match.group('skill'),
        'stat_tier_id': match.group('tier'),
        'attack_def_swapped': match.group('variant') == 'swapped',
        'variant': match.group('variant'),
        'mode_level': f"{match.group('mode')}_L{match.group('boss_level')}",
        'pair_key': scenario_id.rsplit('-', 1)[0],
    }


def parse_vector(token: str) -> List[float]:
    values = []
    for part in token.split('-'):
        values.append(float(part.replace('_', '.')))
    return values


def csv_row_pairs(
    aggregate_path: str,
    score_path: str,
) -> Iterator[Tuple[Dict[str, str], Dict[str, str]]]:
    with open(aggregate_path, newline='', encoding='utf-8') as agg_file:
        with open(score_path, newline='', encoding='utf-8') as score_file:
            agg_reader = csv.DictReader(agg_file)
            score_reader = csv.DictReader(score_file)
            for agg_row, score_row in zip(agg_reader, score_reader):
                if agg_row['scenario_id'] != score_row['scenario_id']:
                    raise ValueError(
                        'Scenario id mismatch between aggregate and score rows: '
                        f"{agg_row['scenario_id']} != {score_row['scenario_id']}"
                    )
                yield agg_row, score_row


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def factor_rows(
    stats_by_level: Dict[str, RunningStats],
    overall: RunningStats,
) -> Tuple[int, float, float, float, str, float, str, float]:
    groups = len(stats_by_level)
    if groups <= 0 or overall.count <= 0 or overall.variance <= 0:
        return 0, 0.0, 0.0, 0.0, '', 0.0, '', 0.0

    between_ss = 0.0
    top_level = ''
    top_mean = -math.inf
    bottom_level = ''
    bottom_mean = math.inf

    for level, stats in stats_by_level.items():
        level_mean = stats.mean
        between_ss += stats.count * ((level_mean - overall.mean) ** 2)
        if level_mean > top_mean:
            top_mean = level_mean
            top_level = level
        if level_mean < bottom_mean:
            bottom_mean = level_mean
            bottom_level = level

    total_ss = overall.variance * overall.count
    eta_squared = between_ss / total_ss if total_ss > 0 else 0.0
    mean_range = top_mean - bottom_mean
    mean_range_pct = 0.0 if overall.mean == 0 else (mean_range / overall.mean) * 100.0
    return (
        groups,
        eta_squared,
        mean_range,
        mean_range_pct,
        top_level,
        top_mean,
        bottom_level,
        bottom_mean,
    )


def write_csv(path: str, header: List[str], rows: Iterable[List[object]]) -> None:
    with open(path, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        for row in rows:
            writer.writerow(row)


def main(argv: List[str]) -> int:
    input_dir = argv[1] if len(argv) > 1 else 'tool/sim_battery/out/full_run'
    aggregate_path = os.path.join(input_dir, 'aggregates_all.csv')
    score_path = os.path.join(input_dir, 'scores_all.csv')
    output_dir = os.path.join(input_dir, 'post_processing')
    ensure_dir(output_dir)

    if not os.path.exists(aggregate_path) or not os.path.exists(score_path):
        raise FileNotFoundError(
            'Missing aggregates_all.csv or scores_all.csv. '
            'Run the simulation first and make sure the merged CSV files exist.'
        )

    raw_factor_score: Dict[str, Dict[str, RunningStats]] = defaultdict(
        lambda: defaultdict(RunningStats)
    )
    raw_factor_damage: Dict[str, Dict[str, RunningStats]] = defaultdict(
        lambda: defaultdict(RunningStats)
    )
    adjusted_factor_score: Dict[str, Dict[str, RunningStats]] = defaultdict(
        lambda: defaultdict(RunningStats)
    )
    mode_level_summary: Dict[str, GroupSummary] = defaultdict(GroupSummary)
    pet_skill_summary: Dict[str, GroupSummary] = defaultdict(GroupSummary)
    tier_summary: Dict[str, GroupSummary] = defaultdict(GroupSummary)
    layout_summary: Dict[str, GroupSummary] = defaultdict(GroupSummary)
    knight_adv_summary: Dict[str, GroupSummary] = defaultdict(GroupSummary)
    boss_adv_summary: Dict[str, GroupSummary] = defaultdict(GroupSummary)
    swapped_pairs: Dict[str, PairComparison] = defaultdict(PairComparison)
    top_scenarios_by_target: Dict[str, List[Tuple[float, str, float]]] = defaultdict(list)
    cell_means: Dict[Tuple[str, str], RunningStats] = defaultdict(RunningStats)
    pending_pairs: Dict[str, Tuple[bool, float, str, str, str]] = {}

    overall_score = RunningStats()
    overall_damage = RunningStats()
    adjusted_overall_score = RunningStats()

    factor_extractors = {
        'mode': lambda meta: str(meta['mode']),
        'boss_level': lambda meta: str(meta['boss_level']),
        'mode_level': lambda meta: str(meta['mode_level']),
        'pet_primary_skill': lambda meta: str(meta['pet_primary_skill']),
        'pet_strategy': lambda meta: str(meta['pet_strategy']),
        'stat_tier_id': lambda meta: str(meta['stat_tier_id']),
        'attack_def_swapped': lambda meta: 'swapped' if bool(meta['attack_def_swapped']) else 'normal',
        'layout': lambda meta: str(meta['layout']),
        'primary_slot': lambda meta: str(meta['primary_slot']),
        'knight_adv_vector': lambda meta: str(meta['knight_adv_vector']),
        'boss_adv_vector': lambda meta: str(meta['boss_adv_vector']),
        'knight_adv_mean': lambda meta: f"{float(meta['knight_adv_mean']):.3f}",
        'boss_adv_mean': lambda meta: f"{float(meta['boss_adv_mean']):.3f}",
    }

    for aggregate_row, score_row in csv_row_pairs(aggregate_path, score_path):
        scenario_id = aggregate_row['scenario_id']
        meta = parse_scenario_id(scenario_id)
        final_score = float(score_row['final_score'])
        mean_damage = float(aggregate_row['mean_total_damage'])
        damage_stddev = float(aggregate_row['stddev_total_damage'])
        completion_rate = float(aggregate_row['completion_rate'])
        survival_rate = float(aggregate_row['survival_rate'])
        mean_turns = float(aggregate_row['mean_turns_survived'])
        mean_pet_casts = float(aggregate_row['mean_pet_cast_count'])

        overall_score.add(final_score)
        overall_damage.add(mean_damage)
        cell_means[(str(meta['mode_level']), str(meta['stat_tier_id']))].add(final_score)

        for factor_name, extractor in factor_extractors.items():
          level = extractor(meta)
          raw_factor_score[factor_name][level].add(final_score)
          raw_factor_damage[factor_name][level].add(mean_damage)

        mode_level_summary[str(meta['mode_level'])].add(
            final_score,
            mean_damage,
            damage_stddev,
            completion_rate,
            survival_rate,
            mean_turns,
            mean_pet_casts,
        )
        pet_skill_summary[str(meta['pet_primary_skill'])].add(
            final_score,
            mean_damage,
            damage_stddev,
            completion_rate,
            survival_rate,
            mean_turns,
            mean_pet_casts,
        )
        tier_summary[str(meta['stat_tier_id'])].add(
            final_score,
            mean_damage,
            damage_stddev,
            completion_rate,
            survival_rate,
            mean_turns,
            mean_pet_casts,
        )
        layout_summary[str(meta['layout'])].add(
            final_score,
            mean_damage,
            damage_stddev,
            completion_rate,
            survival_rate,
            mean_turns,
            mean_pet_casts,
        )
        knight_adv_summary[str(meta['knight_adv_vector'])].add(
            final_score,
            mean_damage,
            damage_stddev,
            completion_rate,
            survival_rate,
            mean_turns,
            mean_pet_casts,
        )
        boss_adv_summary[str(meta['boss_adv_vector'])].add(
            final_score,
            mean_damage,
            damage_stddev,
            completion_rate,
            survival_rate,
            mean_turns,
            mean_pet_casts,
        )

        target_key = str(meta['mode_level'])
        heap = top_scenarios_by_target[target_key]
        heapq.heappush(heap, (final_score, scenario_id, mean_damage))
        if len(heap) > 20:
            heapq.heappop(heap)

        pair_key = str(meta['pair_key'])
        pair_entry = (
            bool(meta['attack_def_swapped']),
            final_score,
            str(meta['mode_level']),
            str(meta['stat_tier_id']),
            str(meta['pet_primary_skill']),
        )
        if pair_key in pending_pairs:
            previous = pending_pairs.pop(pair_key)
            swapped_score = pair_entry[1] if pair_entry[0] else previous[1]
            normal_score = previous[1] if not previous[0] else pair_entry[1]
            uplift = swapped_score - normal_score
            swapped_pairs['overall'].add(uplift)
            swapped_pairs[f"mode_level:{pair_entry[2]}"].add(uplift)
            swapped_pairs[f"stat_tier:{pair_entry[3]}"].add(uplift)
            swapped_pairs[f"pet_skill:{pair_entry[4]}"].add(uplift)
        else:
            pending_pairs[pair_key] = pair_entry

    if pending_pairs:
        raise RuntimeError(f'Unmatched normal/swapped scenario pairs: {len(pending_pairs)}')

    for aggregate_row, score_row in csv_row_pairs(aggregate_path, score_path):
        scenario_id = aggregate_row['scenario_id']
        meta = parse_scenario_id(scenario_id)
        final_score = float(score_row['final_score'])
        cell_key = (str(meta['mode_level']), str(meta['stat_tier_id']))
        adjusted_score = final_score - cell_means[cell_key].mean
        adjusted_overall_score.add(adjusted_score)

        for factor_name, extractor in factor_extractors.items():
            level = extractor(meta)
            adjusted_factor_score[factor_name][level].add(adjusted_score)

    factor_influence_rows = []
    for factor_name in factor_extractors:
        score_groups, score_eta, score_range, score_range_pct, top_level, top_mean, bottom_level, bottom_mean = factor_rows(
            raw_factor_score[factor_name],
            overall_score,
        )
        _, damage_eta, damage_range, damage_range_pct, _, _, _, _ = factor_rows(
            raw_factor_damage[factor_name],
            overall_damage,
        )
        factor_influence_rows.append(
            [
                factor_name,
                score_groups,
                score_eta,
                damage_eta,
                score_range,
                damage_range,
                score_range_pct,
                damage_range_pct,
                top_level,
                top_mean,
                bottom_level,
                bottom_mean,
            ]
        )
    factor_influence_rows.sort(key=lambda row: row[2], reverse=True)

    adjusted_influence_rows = []
    for factor_name in factor_extractors:
        groups, eta, mean_range, _, top_level, top_mean, bottom_level, bottom_mean = factor_rows(
            adjusted_factor_score[factor_name],
            adjusted_overall_score,
        )
        adjusted_influence_rows.append(
            [
                factor_name,
                groups,
                eta,
                mean_range,
                top_level,
                top_mean,
                bottom_level,
                bottom_mean,
            ]
        )
    adjusted_influence_rows.sort(key=lambda row: row[2], reverse=True)

    def summary_rows(source: Dict[str, GroupSummary]) -> List[List[object]]:
        rows = []
        for key, value in sorted(source.items()):
            rows.append(
                [
                    key,
                    value.count,
                    value.score.mean,
                    value.score.stddev,
                    value.damage.mean,
                    value.damage_stddev.mean,
                    value.completion.mean,
                    value.survival.mean,
                    value.turns.mean,
                    value.pet_casts.mean,
                ]
            )
        return rows

    swapped_rows = []
    for key, value in sorted(swapped_pairs.items()):
        if ':' in key:
            group_type, group_value = key.split(':', 1)
        else:
            group_type, group_value = 'overall', 'all'
        swapped_rows.append(
            [
                group_type,
                group_value,
                value.count,
                value.uplift.mean,
                value.uplift.stddev,
                value.uplift.min,
                value.uplift.max,
                value.positive_rate,
            ]
        )

    top_rows = []
    for target, heap in sorted(top_scenarios_by_target.items()):
        ranked = sorted(heap, key=lambda item: item[0], reverse=True)
        for rank, (final_score, scenario_id, mean_damage) in enumerate(ranked, start=1):
            top_rows.append([target, rank, scenario_id, final_score, mean_damage])

    write_csv(
        os.path.join(output_dir, 'factor_influence_raw.csv'),
        [
            'factor',
            'groups',
            'eta_squared_final_score',
            'eta_squared_mean_damage',
            'mean_score_range',
            'mean_damage_range',
            'mean_score_range_pct',
            'mean_damage_range_pct',
            'top_level',
            'top_level_mean_score',
            'bottom_level',
            'bottom_level_mean_score',
        ],
        factor_influence_rows,
    )
    write_csv(
        os.path.join(output_dir, 'factor_influence_adjusted.csv'),
        [
            'factor',
            'groups',
            'eta_squared_adjusted_score',
            'adjusted_mean_range',
            'top_level',
            'top_level_adjusted_mean',
            'bottom_level',
            'bottom_level_adjusted_mean',
        ],
        adjusted_influence_rows,
    )
    write_csv(
        os.path.join(output_dir, 'mode_level_summary.csv'),
        [
            'mode_level',
            'scenario_count',
            'mean_final_score',
            'stddev_final_score',
            'mean_total_damage',
            'mean_stddev_total_damage',
            'mean_completion_rate',
            'mean_survival_rate',
            'mean_turns_survived',
            'mean_pet_cast_count',
        ],
        summary_rows(mode_level_summary),
    )
    write_csv(
        os.path.join(output_dir, 'pet_skill_summary.csv'),
        [
            'pet_primary_skill',
            'scenario_count',
            'mean_final_score',
            'stddev_final_score',
            'mean_total_damage',
            'mean_stddev_total_damage',
            'mean_completion_rate',
            'mean_survival_rate',
            'mean_turns_survived',
            'mean_pet_cast_count',
        ],
        summary_rows(pet_skill_summary),
    )
    write_csv(
        os.path.join(output_dir, 'stat_tier_summary.csv'),
        [
            'stat_tier_id',
            'scenario_count',
            'mean_final_score',
            'stddev_final_score',
            'mean_total_damage',
            'mean_stddev_total_damage',
            'mean_completion_rate',
            'mean_survival_rate',
            'mean_turns_survived',
            'mean_pet_cast_count',
        ],
        summary_rows(tier_summary),
    )
    write_csv(
        os.path.join(output_dir, 'layout_summary.csv'),
        [
            'layout',
            'scenario_count',
            'mean_final_score',
            'stddev_final_score',
            'mean_total_damage',
            'mean_stddev_total_damage',
            'mean_completion_rate',
            'mean_survival_rate',
            'mean_turns_survived',
            'mean_pet_cast_count',
        ],
        summary_rows(layout_summary),
    )
    write_csv(
        os.path.join(output_dir, 'knight_adv_vector_summary.csv'),
        [
            'knight_adv_vector',
            'scenario_count',
            'mean_final_score',
            'stddev_final_score',
            'mean_total_damage',
            'mean_stddev_total_damage',
            'mean_completion_rate',
            'mean_survival_rate',
            'mean_turns_survived',
            'mean_pet_cast_count',
        ],
        summary_rows(knight_adv_summary),
    )
    write_csv(
        os.path.join(output_dir, 'boss_adv_vector_summary.csv'),
        [
            'boss_adv_vector',
            'scenario_count',
            'mean_final_score',
            'stddev_final_score',
            'mean_total_damage',
            'mean_stddev_total_damage',
            'mean_completion_rate',
            'mean_survival_rate',
            'mean_turns_survived',
            'mean_pet_cast_count',
        ],
        summary_rows(boss_adv_summary),
    )
    write_csv(
        os.path.join(output_dir, 'swapped_vs_normal.csv'),
        [
            'group_type',
            'group_value',
            'pair_count',
            'mean_score_uplift_swapped_minus_normal',
            'stddev_score_uplift',
            'min_score_uplift',
            'max_score_uplift',
            'swapped_win_rate',
        ],
        swapped_rows,
    )
    write_csv(
        os.path.join(output_dir, 'top_scenarios_by_mode_level.csv'),
        [
            'mode_level',
            'rank',
            'scenario_id',
            'final_score',
            'mean_total_damage',
        ],
        top_rows,
    )

    raw_top = factor_influence_rows[:5]
    adjusted_top = adjusted_influence_rows[:5]
    overall_swapped = swapped_pairs['overall']
    mode_level_best = max(
        mode_level_summary.items(),
        key=lambda item: item[1].score.mean,
    )
    mode_level_worst = min(
        mode_level_summary.items(),
        key=lambda item: item[1].score.mean,
    )

    md_path = os.path.join(output_dir, 'post_processing_summary.md')
    with open(md_path, 'w', encoding='utf-8') as handle:
        handle.write('# Boss Simulation Post-Processing\n\n')
        handle.write(f'- Input rows: {overall_score.count}\n')
        handle.write(f'- Mean final score: {overall_score.mean:.3f}\n')
        handle.write(f'- Mean total damage: {overall_damage.mean:.3f}\n')
        handle.write(f'- Mean adjusted score (mode_level + stat_tier centered): {adjusted_overall_score.mean:.3f}\n')
        handle.write('\n## Strongest Raw Factors\n\n')
        for row in raw_top:
            handle.write(
                f"- `{row[0]}`: eta^2 score={row[2]:.6f}, eta^2 damage={row[3]:.6f}, "
                f"score range={row[6]:.2f}%, top=`{row[8]}`, bottom=`{row[10]}`\n"
            )
        handle.write('\n## Strongest Adjusted Factors\n\n')
        for row in adjusted_top:
            handle.write(
                f"- `{row[0]}`: eta^2 adjusted score={row[2]:.6f}, "
                f"adjusted range={row[3]:.3f}, top=`{row[4]}`, bottom=`{row[6]}`\n"
            )
        handle.write('\n## Swapped vs Normal\n\n')
        handle.write(
            f"- Mean uplift (swapped - normal): {overall_swapped.uplift.mean:.3f}\n"
        )
        handle.write(
            f"- Uplift stddev: {overall_swapped.uplift.stddev:.3f}\n"
        )
        handle.write(
            f"- Swapped win rate: {overall_swapped.positive_rate * 100.0:.2f}%\n"
        )
        handle.write('\n## Mode Level Extremes\n\n')
        handle.write(
            f"- Best mean score: `{mode_level_best[0]}` -> {mode_level_best[1].score.mean:.3f}\n"
        )
        handle.write(
            f"- Worst mean score: `{mode_level_worst[0]}` -> {mode_level_worst[1].score.mean:.3f}\n"
        )
        handle.write('\n## Outputs\n\n')
        handle.write('- `factor_influence_raw.csv`\n')
        handle.write('- `factor_influence_adjusted.csv`\n')
        handle.write('- `mode_level_summary.csv`\n')
        handle.write('- `pet_skill_summary.csv`\n')
        handle.write('- `stat_tier_summary.csv`\n')
        handle.write('- `layout_summary.csv`\n')
        handle.write('- `knight_adv_vector_summary.csv`\n')
        handle.write('- `boss_adv_vector_summary.csv`\n')
        handle.write('- `swapped_vs_normal.csv`\n')
        handle.write('- `top_scenarios_by_mode_level.csv`\n')

    print(f'Post-processing complete. Outputs written to: {output_dir}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
