import 'package:flutter/material.dart';

import '../widgets.dart';

class HomeFaqItem {
  final String question;
  final String answer;

  const HomeFaqItem({
    required this.question,
    required this.answer,
  });
}

class HomeFaqSection extends StatelessWidget {
  final String Function(String key, String fallback) t;

  const HomeFaqSection({
    super.key,
    required this.t,
  });

  List<HomeFaqItem> _buildItems() {
    return <HomeFaqItem>[
      HomeFaqItem(
        question: t(
          'home.faq.q1.question',
          'Are you the sole developer of this app?',
        ),
        answer: t(
          'home.faq.q1.answer',
          'Yes. I designed and developed the app myself, with modern development tools helping speed up parts of the workflow.',
        ),
      ),
      HomeFaqItem(
        question: t(
          'home.faq.q2.question',
          'Which server do you play on?',
        ),
        answer: t(
          'home.faq.q2.answer',
          'I play on the Global server.',
        ),
      ),
      HomeFaqItem(
        question: t(
          'home.faq.q3.question',
          'What guild / family are you part of?',
        ),
        answer: t(
          'home.faq.q3.answer',
          'I am part of Imperial Knights, the top guild in the Imperial Family.',
        ),
      ),
      HomeFaqItem(
        question: t(
          'home.faq.q4.question',
          'Do you welcome feedback on newly released features?',
        ),
        answer: t(
          'home.faq.q4.answer',
          'Absolutely. I always appreciate feedback and new feature proposals, so feel free to contact me on LINE, Discord, or by email at kedraidcalcsupp@gmail.com.',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final faqItems = _buildItems();
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: CompactCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('home.faq.title', 'FAQ'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'home.faq.subtitle',
                'A few quick answers about the app, the developer and where to reach out.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < faqItems.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text(
                  faqItems[i].question,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                iconColor: cs.primary,
                collapsedIconColor: cs.onSurfaceVariant,
                children: [
                  Text(
                    faqItems[i].answer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
