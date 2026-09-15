// DailyQuestsData.swift
// Paar-Tagesquest pool — 48 small, doable-today couple missions (DE/EN).
// The day's 3 quests are picked deterministically from coupleId + dateKey
// (see DailyQuestsLogic.swift), so both partners always see the same set.

import Foundation

extension ContentPack {
    static let dailyQuests: [DailyQuestItem] = [
        DailyQuestItem(id: 1, emoji: "🍳", text: LText(de: "Schickt euch heute ein Foto von eurem Frühstück.", en: "Send each other a photo of your breakfast today.")),
        DailyQuestItem(id: 2, emoji: "💌", text: LText(de: "Schreib deinem Schatz, wofür du heute dankbar bist.", en: "Tell your love what you're grateful for today.")),
        DailyQuestItem(id: 3, emoji: "📸", text: LText(de: "Schickt ein Selfie von eurem aktuellen Ausblick.", en: "Send a selfie with your current view.")),
        DailyQuestItem(id: 4, emoji: "🎵", text: LText(de: "Schickt euch einen Song, der euch an den anderen erinnert.", en: "Send each other a song that reminds you of them.")),
        DailyQuestItem(id: 5, emoji: "☕️", text: LText(de: "Erzählt euch das Schönste an eurem heutigen Tag.", en: "Tell each other the best part of your day.")),
        DailyQuestItem(id: 6, emoji: "🤗", text: LText(de: "Gönnt euch eine 20-Sekunden-Umarmung — live oder per Video.", en: "Treat yourselves to a 20-second hug — in person or over video.")),
        DailyQuestItem(id: 7, emoji: "💬", text: LText(de: "Nennt euch gegenseitig drei Dinge, die ihr aneinander liebt.", en: "Name three things you love about each other.")),
        DailyQuestItem(id: 8, emoji: "🌇", text: LText(de: "Schickt euch JETZT ein Foto vom Himmel über euch.", en: "Send a photo of the sky above you RIGHT NOW.")),
        DailyQuestItem(id: 9, emoji: "😂", text: LText(de: "Schickt euch das lustigste Meme, das euch heute begegnet.", en: "Send each other the funniest meme you find today.")),
        DailyQuestItem(id: 10, emoji: "🥤", text: LText(de: "Trinkt heute zur selben Zeit dasselbe Getränk.", en: "Have the same drink at the same time today.")),
        DailyQuestItem(id: 11, emoji: "📞", text: LText(de: "Ruft euch für fünf Minuten an — nur um Hallo zu sagen.", en: "Call each other for five minutes — just to say hi.")),
        DailyQuestItem(id: 12, emoji: "✍️", text: LText(de: "Schreibt ein Zwei-Zeilen-Gedicht übereinander.", en: "Write a two-line poem about each other.")),
        DailyQuestItem(id: 13, emoji: "🚶", text: LText(de: "Macht einen kurzen Spaziergang und schickt ein Beweisfoto.", en: "Take a short walk and send photo proof.")),
        DailyQuestItem(id: 14, emoji: "🍫", text: LText(de: "Überrasch deinen Schatz heute mit einer kleinen Süßigkeit.", en: "Surprise your love with a little treat today.")),
        DailyQuestItem(id: 15, emoji: "🎨", text: LText(de: "Malt euch gegenseitig etwas auf dem Pärchen-Canvas.", en: "Draw something for each other on the couple canvas.")),
        DailyQuestItem(id: 16, emoji: "🎲", text: LText(de: "Spielt heute zusammen eine Runde in der Spielhalle.", en: "Play one round together in the arcade today.")),
        DailyQuestItem(id: 17, emoji: "💭", text: LText(de: "Erzählt euch von einem Traum — nachts geträumt oder fürs Leben.", en: "Share a dream — from last night or for your life.")),
        DailyQuestItem(id: 18, emoji: "🕰️", text: LText(de: "Teilt eine Lieblingserinnerung aus eurer Anfangszeit.", en: "Share a favorite memory from when you first met.")),
        DailyQuestItem(id: 19, emoji: "🌟", text: LText(de: "Mach ein ehrliches Kompliment, das NICHTS mit Aussehen zu tun hat.", en: "Give a sincere compliment that has NOTHING to do with looks.")),
        DailyQuestItem(id: 20, emoji: "🍽️", text: LText(de: "Plant zusammen, was es morgen zu essen gibt.", en: "Plan tomorrow's dinner together.")),
        DailyQuestItem(id: 21, emoji: "📖", text: LText(de: "Empfiehl deinem Schatz etwas zum Lesen, Hören oder Schauen.", en: "Recommend your love something to read, listen to, or watch.")),
        DailyQuestItem(id: 22, emoji: "🤳", text: LText(de: "Schickt ein 10-Sekunden-Video aus eurem Tag.", en: "Send a 10-second video from your day.")),
        DailyQuestItem(id: 23, emoji: "🧦", text: LText(de: "Foto-Beweis: Wer trägt heute die schöneren Socken?", en: "Photo proof: who's wearing the better socks today?")),
        DailyQuestItem(id: 24, emoji: "🫶", text: LText(de: "Sagt euch heute dreimal „Ich liebe dich\u{201C} — verteilt über den Tag.", en: "Say \"I love you\" three times today — spread across the day.")),
        DailyQuestItem(id: 25, emoji: "☀️", text: LText(de: "Beschreibe deinen Morgen in genau fünf Emojis.", en: "Describe your morning in exactly five emojis.")),
        DailyQuestItem(id: 26, emoji: "🎧", text: LText(de: "Hört gleichzeitig denselben Song — zählt gemeinsam runter.", en: "Listen to the same song at the same time — count down together.")),
        DailyQuestItem(id: 27, emoji: "🍀", text: LText(de: "Schickt ein Foto von etwas Grünem auf deinem Weg.", en: "Send a photo of something green you pass today.")),
        DailyQuestItem(id: 28, emoji: "💤", text: LText(de: "Erzählt, wovon ihr letzte Nacht geträumt habt — oder erfindet es frech.", en: "Share what you dreamed last night — or cheekily make it up.")),
        DailyQuestItem(id: 29, emoji: "🏆", text: LText(de: "Lobt euch für etwas, das der andere diese Woche geschafft hat.", en: "Praise each other for something you accomplished this week.")),
        DailyQuestItem(id: 30, emoji: "🗺️", text: LText(de: "Schlag einen Ort für euer nächstes Date vor.", en: "Suggest a place for your next date.")),
        DailyQuestItem(id: 31, emoji: "📵", text: LText(de: "Eine Stunde handyfrei — erzählt euch danach, wie es war.", en: "One phone-free hour — tell each other how it went.")),
        DailyQuestItem(id: 32, emoji: "🧸", text: LText(de: "Schickt ein Foto von etwas, das dich an euren Anfang erinnert.", en: "Send a photo of something that reminds you of your beginning.")),
        DailyQuestItem(id: 33, emoji: "🍋", text: LText(de: "Probiert heute etwas Neues und berichtet dem anderen.", en: "Try something new today and report back.")),
        DailyQuestItem(id: 34, emoji: "💃", text: LText(de: "Schickt ein 5-Sekunden-Tanzvideo. Keine Ausreden!", en: "Send a 5-second dance video. No excuses!")),
        DailyQuestItem(id: 35, emoji: "🌙", text: LText(de: "Schickt euch heute Abend eine Gute-Nacht-Sprachnachricht.", en: "Send each other a goodnight voice message tonight.")),
        DailyQuestItem(id: 36, emoji: "🧩", text: LText(de: "Stellt euch gegenseitig ein Rätsel — wer löst es schneller?", en: "Give each other a riddle — who solves it faster?")),
        DailyQuestItem(id: 37, emoji: "❓", text: LText(de: "Stellt eine Frage, die ihr euch noch NIE gestellt habt.", en: "Ask a question you've NEVER asked each other before.")),
        DailyQuestItem(id: 38, emoji: "🎁", text: LText(de: "Verstecke irgendwo im heutigen Chat ein Kompliment.", en: "Hide a compliment somewhere in today's chat.")),
        DailyQuestItem(id: 39, emoji: "🚿", text: LText(de: "Sing heute unter der Dusche — und gib es hinterher zu.", en: "Sing in the shower today — and admit it afterwards.")),
        DailyQuestItem(id: 40, emoji: "🥇", text: LText(de: "Mini-Wettrennen: Wer schickt zuerst ein Foto von Wasser?", en: "Mini race: who sends a photo of water first?")),
        DailyQuestItem(id: 41, emoji: "🌻", text: LText(de: "Foto der schönsten Sache, die du heute gesehen hast.", en: "Photo of the prettiest thing you saw today.")),
        DailyQuestItem(id: 42, emoji: "🤝", text: LText(de: "Bedank dich für etwas Konkretes aus der letzten Woche.", en: "Say thanks for something specific from the past week.")),
        DailyQuestItem(id: 43, emoji: "🎬", text: LText(de: "Zitiere euren Lieblingsfilm — dein Schatz muss ihn erraten.", en: "Quote your favorite movie — your love has to guess it.")),
        DailyQuestItem(id: 44, emoji: "🧣", text: LText(de: "Trag heute etwas, das dein Schatz an dir mag — Foto-Beweis!", en: "Wear something your love likes on you today — photo proof!")),
        DailyQuestItem(id: 45, emoji: "📅", text: LText(de: "Blockt euch heute Abend 15 Minuten nur für euch zwei.", en: "Block off 15 minutes tonight just for the two of you.")),
        DailyQuestItem(id: 46, emoji: "🍦", text: LText(de: "Beschreibt euren heutigen Tag als Eissorte.", en: "Describe your day today as an ice cream flavor.")),
        DailyQuestItem(id: 47, emoji: "💪", text: LText(de: "Macht zusammen (oder parallel) zehn Kniebeugen.", en: "Do ten squats together (or in parallel).")),
        DailyQuestItem(id: 48, emoji: "🔮", text: LText(de: "Sag dem anderen eine schöne Sache für morgen voraus.", en: "Predict one lovely thing for the other's tomorrow."))
    ]
}
