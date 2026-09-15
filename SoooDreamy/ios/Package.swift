// swift-tools-version: 5.9
// Linux-runnable SwiftPM package covering the pure-logic (Foundation-only)
// subset of the SoooDreamy iOS app. The full app is built by XcodeGen from
// project.yml — this manifest exists ONLY so `swift test` can exercise the
// content packs, date helpers, seeded RNG and localization tables on Linux/CI.
// Do not add SwiftUI/UIKit files to `sources`.
import PackageDescription

let package = Package(
    name: "SoooDreamyLogic",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SoooDreamyLogic", targets: ["SoooDreamyLogic"])
    ],
    targets: [
        .target(
            name: "SoooDreamyLogic",
            path: ".",
            sources: [
                "SoooDreamy/Content/ContentModels.swift",
                "SoooDreamy/Content/Data/DailyQuestionsData.swift",
                "SoooDreamy/Content/Data/QuizData.swift",
                "SoooDreamy/Content/Data/ThisOrThatData.swift",
                "SoooDreamy/Content/Data/WouldYouRatherData.swift",
                "SoooDreamy/Content/Data/TruthOrDareData.swift",
                "SoooDreamy/Content/Data/Questions36Data.swift",
                "SoooDreamy/Content/Data/DateIdeasData.swift",
                "SoooDreamy/Content/Data/WordleWordsData.swift",
                "SoooDreamy/Content/Data/EmojiRiddlesData.swift",
                "SoooDreamy/Content/Data/QuizDuelData.swift",
                "SoooDreamy/Content/CoupleGamesLogic.swift",
                "SoooDreamy/Content/BattleshipLogic.swift",
                "SoooDreamy/Content/PictionaryLogic.swift",
                "SoooDreamy/Content/Data/PictionaryWordsData.swift",
                "SoooDreamy/Content/KniffelLogic.swift",
                "SoooDreamy/Content/MovieRouletteLogic.swift",
                "SoooDreamy/Content/Data/MovieRouletteData.swift",
                "SoooDreamy/Content/MovieNightLogic.swift",
                "SoooDreamy/Content/StadtLandFlussLogic.swift",
                "SoooDreamy/Content/TwoTruthsLogic.swift",
                "SoooDreamy/Content/DailyQuestsLogic.swift",
                "SoooDreamy/Content/TournamentLogic.swift",
                "SoooDreamy/Content/ReplayLogic.swift",
                "SoooDreamy/Content/Data/DailyQuestsData.swift",
                "Shared/SharedBridge.swift",
                "Shared/WidgetStudio.swift",
                "Shared/LiveActivityConfig.swift",
                "Shared/TouchEmoji.swift",
                "SoooDreamy/Core/SeededRandom.swift",
                "SoooDreamy/Core/CommitReveal.swift",
                "SoooDreamy/Core/HapticPatternKit.swift",
                "SoooDreamy/Core/DelightRules.swift",
                "SoooDreamy/Core/LevelMath.swift",
                "SoooDreamy/Core/NextStepRules.swift",
                "SoooDreamy/Core/Routes.swift",
                "SoooDreamy/Core/SearchIndex.swift",
                "SoooDreamy/Core/Invitation.swift",
                "SoooDreamy/Core/ServerURLPolicy.swift",
                "SoooDreamy/Core/SeasonLogic.swift",
                "SoooDreamy/Core/OfflineOutbox.swift",
                "SoooDreamy/Core/CoreColdCache.swift",
                "SoooDreamy/Core/FIFOQueue.swift",
                "SoooDreamy/Core/L10n.swift",
                "SoooDreamy/Core/CoreStrings.swift",
                "SoooDreamy/DesignSystem/DesignL10n.swift",
                "SoooDreamy/Features/Messages/ChatL10n.swift",
                "SoooDreamy/Features/Games/GamesL10n.swift",
                "SoooDreamy/Features/Memories/MemoriesL10n.swift",
                "SoooDreamy/Features/Today/PlatformL10n.swift",
                "SoooDreamy/Features/Us/RitualsL10n.swift"
            ]
        ),
        .testTarget(
            name: "SoooDreamyLogicTests",
            dependencies: ["SoooDreamyLogic"],
            path: "LogicTests"
        )
    ]
)
