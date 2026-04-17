from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LANGS_DIR = ROOT / "assets" / "langs"

TRANSLATIONS = {
    "en": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "A few quick answers about the app, the developer and where to reach out.",
        "home.faq.q1.question": "Are you the sole developer of this app?",
        "home.faq.q1.answer": "Yes. I designed and developed the app myself, with modern development tools helping speed up parts of the workflow.",
        "home.faq.q2.question": "Which server do you play on?",
        "home.faq.q2.answer": "I play on the Global server.",
        "home.faq.q3.question": "What guild / family are you part of?",
        "home.faq.q3.answer": "I am part of Imperial Knights, the top guild in the Imperial Family.",
        "home.faq.q4.question": "Do you welcome feedback on newly released features?",
        "home.faq.q4.answer": "Absolutely. I always appreciate feedback and new feature proposals, so feel free to contact me on LINE or Discord.",
    },
    "it": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "Alcune risposte rapide sull'app, sullo sviluppatore e su come contattarmi.",
        "home.faq.q1.question": "Sei l'unico sviluppatore di questa app?",
        "home.faq.q1.answer": "Sì. Ho progettato e sviluppato l'app personalmente, usando anche moderni strumenti di sviluppo per velocizzare parte del lavoro.",
        "home.faq.q2.question": "Su quale server giochi?",
        "home.faq.q2.answer": "Gioco sul server Global.",
        "home.faq.q3.question": "Di quale gilda / family fai parte?",
        "home.faq.q3.answer": "Faccio parte degli Imperial Knights, la top guild della Imperial Family.",
        "home.faq.q4.question": "Accetti feedback sulle nuove funzionalità?",
        "home.faq.q4.answer": "Assolutamente sì. Apprezzo sempre feedback e proposte di nuove funzioni, quindi sentiti libero di contattarmi su LINE o Discord.",
    },
    "fr": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "Quelques réponses rapides sur l'app, le développeur et la façon de me contacter.",
        "home.faq.q1.question": "Es-tu l'unique développeur de cette app ?",
        "home.faq.q1.answer": "Oui. J'ai conçu et développé l'app moi-même, avec des outils de développement modernes pour accélérer certaines parties du travail.",
        "home.faq.q2.question": "Sur quel serveur joues-tu ?",
        "home.faq.q2.answer": "Je joue sur le serveur Global.",
        "home.faq.q3.question": "De quelle guilde / famille fais-tu partie ?",
        "home.faq.q3.answer": "Je fais partie des Imperial Knights, la meilleure guilde de l'Imperial Family.",
        "home.faq.q4.question": "Acceptes-tu les retours sur les nouvelles fonctionnalités ?",
        "home.faq.q4.answer": "Absolument. J'apprécie toujours les retours et les propositions de nouvelles fonctionnalités, alors n'hésite pas à me contacter sur LINE ou Discord.",
    },
    "de": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "Ein paar schnelle Antworten zur App, zum Entwickler und dazu, wie du mich erreichen kannst.",
        "home.faq.q1.question": "Bist du der alleinige Entwickler dieser App?",
        "home.faq.q1.answer": "Ja. Ich habe die App selbst entworfen und entwickelt und dabei moderne Entwicklungstools genutzt, um Teile des Workflows zu beschleunigen.",
        "home.faq.q2.question": "Auf welchem Server spielst du?",
        "home.faq.q2.answer": "Ich spiele auf dem Global-Server.",
        "home.faq.q3.question": "Zu welcher Gilde / Familie gehörst du?",
        "home.faq.q3.answer": "Ich bin bei Imperial Knights, der Top-Gilde der Imperial Family.",
        "home.faq.q4.question": "Nimmst du Feedback zu neuen Funktionen an?",
        "home.faq.q4.answer": "Auf jeden Fall. Ich freue mich immer über Feedback und Vorschläge für neue Features, also melde dich gern über LINE oder Discord.",
    },
    "es": {
        "home.faq.title": "Preguntas frecuentes",
        "home.faq.subtitle": "Algunas respuestas rápidas sobre la app, el desarrollador y cómo contactarme.",
        "home.faq.q1.question": "¿Eres el único desarrollador de esta app?",
        "home.faq.q1.answer": "Sí. Diseñé y desarrollé la app yo mismo, usando herramientas modernas de desarrollo para acelerar partes del trabajo.",
        "home.faq.q2.question": "¿En qué servidor juegas?",
        "home.faq.q2.answer": "Juego en el servidor Global.",
        "home.faq.q3.question": "¿De qué guild / family formas parte?",
        "home.faq.q3.answer": "Formo parte de Imperial Knights, la guild número uno de la Imperial Family.",
        "home.faq.q4.question": "¿Aceptas comentarios sobre las nuevas funciones?",
        "home.faq.q4.answer": "Claro que sí. Siempre agradezco los comentarios y las propuestas de nuevas funciones, así que no dudes en contactarme por LINE o Discord.",
    },
    "nl": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "Een paar snelle antwoorden over de app, de ontwikkelaar en hoe je contact kunt opnemen.",
        "home.faq.q1.question": "Ben jij de enige ontwikkelaar van deze app?",
        "home.faq.q1.answer": "Ja. Ik heb de app zelf ontworpen en ontwikkeld, met moderne ontwikkeltools om delen van het werk sneller te maken.",
        "home.faq.q2.question": "Op welke server speel je?",
        "home.faq.q2.answer": "Ik speel op de Global-server.",
        "home.faq.q3.question": "Van welke guild / family maak je deel uit?",
        "home.faq.q3.answer": "Ik maak deel uit van Imperial Knights, de topguild van de Imperial Family.",
        "home.faq.q4.question": "Sta je open voor feedback op nieuwe functies?",
        "home.faq.q4.answer": "Zeker. Ik waardeer feedback en nieuwe feature-ideeën altijd, dus neem gerust contact met me op via LINE of Discord.",
    },
    "da": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "Et par hurtige svar om appen, udvikleren og hvordan du kan kontakte mig.",
        "home.faq.q1.question": "Er du den eneste udvikler af denne app?",
        "home.faq.q1.answer": "Ja. Jeg har selv designet og udviklet appen og brugt moderne udviklingsværktøjer til at gøre dele af arbejdet hurtigere.",
        "home.faq.q2.question": "Hvilken server spiller du på?",
        "home.faq.q2.answer": "Jeg spiller på Global-serveren.",
        "home.faq.q3.question": "Hvilken guild / family er du en del af?",
        "home.faq.q3.answer": "Jeg er en del af Imperial Knights, topguilden i Imperial Family.",
        "home.faq.q4.question": "Tager du imod feedback på nye funktioner?",
        "home.faq.q4.answer": "Helt sikkert. Jeg sætter altid pris på feedback og forslag til nye funktioner, så du er meget velkommen til at kontakte mig på LINE eller Discord.",
    },
    "tr": {
        "home.faq.title": "SSS",
        "home.faq.subtitle": "Uygulama, geliştirici ve bana nasıl ulaşabileceğiniz hakkında birkaç hızlı cevap.",
        "home.faq.q1.question": "Bu uygulamanın tek geliştiricisi sen misin?",
        "home.faq.q1.answer": "Evet. Uygulamayı kendim tasarlayıp geliştirdim ve iş akışının bazı kısımlarını hızlandırmak için modern geliştirme araçlarından yararlandım.",
        "home.faq.q2.question": "Hangi sunucuda oynuyorsun?",
        "home.faq.q2.answer": "Global sunucusunda oynuyorum.",
        "home.faq.q3.question": "Hangi guild / family içindesin?",
        "home.faq.q3.answer": "Imperial Family içindeki en üst guild olan Imperial Knights'ın bir parçasıyım.",
        "home.faq.q4.question": "Yeni çıkan özellikler için geri bildirim kabul ediyor musun?",
        "home.faq.q4.answer": "Kesinlikle. Geri bildirimleri ve yeni özellik önerilerini her zaman memnuniyetle karşılıyorum, bu yüzden LINE veya Discord üzerinden bana yazmaktan çekinme.",
    },
    "pl": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "Kilka szybkich odpowiedzi o aplikacji, twórcy i sposobie kontaktu.",
        "home.faq.q1.question": "Czy jesteś jedynym twórcą tej aplikacji?",
        "home.faq.q1.answer": "Tak. Sam zaprojektowałem i stworzyłem aplikację, korzystając także z nowoczesnych narzędzi programistycznych, aby przyspieszyć część pracy.",
        "home.faq.q2.question": "Na jakim serwerze grasz?",
        "home.faq.q2.answer": "Gram na serwerze Global.",
        "home.faq.q3.question": "Do jakiej guild / family należysz?",
        "home.faq.q3.answer": "Należę do Imperial Knights, czołowej gildii w Imperial Family.",
        "home.faq.q4.question": "Czy przyjmujesz opinie o nowych funkcjach?",
        "home.faq.q4.answer": "Oczywiście. Zawsze doceniam opinie i propozycje nowych funkcji, więc śmiało skontaktuj się ze mną przez LINE lub Discord.",
    },
    "ar": {
        "home.faq.title": "الأسئلة الشائعة",
        "home.faq.subtitle": "بعض الإجابات السريعة عن التطبيق والمطور وكيفية التواصل معي.",
        "home.faq.q1.question": "هل أنت المطور الوحيد لهذا التطبيق؟",
        "home.faq.q1.answer": "نعم. لقد صممت وطورت التطبيق بنفسي، مع الاستفادة من أدوات تطوير حديثة لتسريع بعض أجزاء العمل.",
        "home.faq.q2.question": "على أي خادم تلعب؟",
        "home.faq.q2.answer": "ألعب على خادم Global.",
        "home.faq.q3.question": "ما هي الـ guild / family التي تنتمي إليها؟",
        "home.faq.q3.answer": "أنا جزء من Imperial Knights، وهي أفضل guild ضمن Imperial Family.",
        "home.faq.q4.question": "هل ترحب بالملاحظات حول الميزات الجديدة؟",
        "home.faq.q4.answer": "بالتأكيد. أقدّر دائمًا الملاحظات واقتراحات الميزات الجديدة، لذلك لا تتردد في التواصل معي عبر LINE أو Discord.",
    },
    "ru": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "Несколько быстрых ответов о приложении, разработчике и способах связи со мной.",
        "home.faq.q1.question": "Ты единственный разработчик этого приложения?",
        "home.faq.q1.answer": "Да. Я сам спроектировал и разработал приложение, используя современные инструменты разработки, чтобы ускорить часть работы.",
        "home.faq.q2.question": "На каком сервере ты играешь?",
        "home.faq.q2.answer": "Я играю на сервере Global.",
        "home.faq.q3.question": "В какой guild / family ты состоишь?",
        "home.faq.q3.answer": "Я состою в Imperial Knights, топ-гильдии в Imperial Family.",
        "home.faq.q4.question": "Ты открыт к отзывам о новых функциях?",
        "home.faq.q4.answer": "Конечно. Я всегда ценю отзывы и предложения новых функций, так что смело пиши мне в LINE или Discord.",
    },
    "zh": {
        "home.faq.title": "常见问题",
        "home.faq.subtitle": "关于这款应用、开发者以及如何联系我的一些快速说明。",
        "home.faq.q1.question": "你是这款应用的唯一开发者吗？",
        "home.faq.q1.answer": "是的。这款应用由我独立设计和开发，同时也会使用现代开发工具来加快部分工作流程。",
        "home.faq.q2.question": "你在哪个服务器游玩？",
        "home.faq.q2.answer": "我在 Global 服务器游玩。",
        "home.faq.q3.question": "你属于哪个 guild / family？",
        "home.faq.q3.answer": "我属于 Imperial Knights，它是 Imperial Family 中的顶级公会。",
        "home.faq.q4.question": "你欢迎大家对新功能提出反馈吗？",
        "home.faq.q4.answer": "当然欢迎。我一直都很重视反馈和新功能建议，所以你可以随时通过 LINE 或 Discord 联系我。",
    },
    "ja": {
        "home.faq.title": "FAQ",
        "home.faq.subtitle": "このアプリ、開発者、そして連絡方法についての簡単な回答です。",
        "home.faq.q1.question": "このアプリはあなた一人で開発しているのですか？",
        "home.faq.q1.answer": "はい。アプリの設計と開発は私自身が行っており、作業を効率化するために最新の開発ツールも活用しています。",
        "home.faq.q2.question": "どのサーバーでプレイしていますか？",
        "home.faq.q2.answer": "Global サーバーでプレイしています。",
        "home.faq.q3.question": "どの guild / family に所属していますか？",
        "home.faq.q3.answer": "私は Imperial Family のトップギルドである Imperial Knights に所属しています。",
        "home.faq.q4.question": "新機能に対するフィードバックは歓迎ですか？",
        "home.faq.q4.answer": "もちろんです。フィードバックや新機能の提案はいつでも歓迎しているので、LINE または Discord で気軽に連絡してください。",
    },
}


def main() -> None:
    for lang, updates in TRANSLATIONS.items():
        path = LANGS_DIR / f"{lang}.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data.update(updates)
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )


if __name__ == "__main__":
    main()
