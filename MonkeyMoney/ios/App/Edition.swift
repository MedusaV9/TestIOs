import Foundation

/// Build flavour. The League Edition (compile flag `LEAGUE_EDITION`, target
/// `MonkeyMoneyLeague`) ships the same show with nothing but League-of-Legends
/// questions: the catalogue is filtered at launch, the question set is locked
/// to Runeterra and the branding says so.
enum Edition {
    #if LEAGUE_EDITION
    static let isLeague = true
    #else
    static let isLeague = false
    #endif

    static var name: String { isLeague ? "League Edition" : "" }
    static var shortName: String { isLeague ? "LEAGUE" : "" }
    static var questionPool: [String] { isLeague ? QuestionSets.set(QuestionSets.leagueId)?.pool ?? [] : [] }
    static var defaultSet: String { isLeague ? QuestionSets.leagueId : QuestionSets.alleId }

    /// Restrict a loaded catalogue to the edition's questions.
    static func catalog(_ loaded: ContentCatalog) -> ContentCatalog {
        isLeague ? loaded.filtered(pool: questionPool) : loaded
    }

    /// Default draft settings for a new show in this edition.
    static func defaultSettings(modus: Modus = .klassik) -> MatchSettings {
        var s = MatchSettings(modus: modus)
        s.applyQuestionSet(defaultSet)
        return s
    }
}
