import Foundation

// MARK: - LanguageUtils

/// Utility functions for language code recognition and matching.
enum LanguageUtils {
    /// Common ISO 639-1/639-2/639-3 language codes.
    static let recognizedCodes: Set<String> = [
        // ISO 639-1 (2-letter)
        "aa", "ab", "af", "ak", "am", "an", "ar", "as", "av", "ay", "az",
        "ba", "be", "bg", "bh", "bi", "bm", "bn", "bo", "br", "bs",
        "ca", "ce", "ch", "co", "cr", "cs", "cu", "cv", "cy",
        "da", "de", "dv", "dz",
        "ee", "el", "en", "eo", "es", "et", "eu",
        "fa", "ff", "fi", "fj", "fo", "fr", "fy",
        "ga", "gd", "gl", "gn", "gu", "gv",
        "ha", "he", "hi", "ho", "hr", "ht", "hu", "hy", "hz",
        "ia", "id", "ie", "ig", "ii", "ik", "io", "is", "it", "iu",
        "ja", "jv",
        "ka", "kg", "ki", "kj", "kk", "kl", "km", "kn", "ko", "kr", "ks", "ku", "kv", "kw", "ky",
        "la", "lb", "lg", "li", "ln", "lo", "lt", "lu", "lv",
        "mg", "mh", "mi", "mk", "ml", "mn", "mr", "ms", "mt", "my",
        "na", "nb", "nd", "ne", "ng", "nl", "nn", "no", "nr", "nv", "ny",
        "oc", "oj", "om", "or", "os",
        "pa", "pi", "pl", "ps", "pt",
        "qu",
        "rm", "rn", "ro", "ru", "rw",
        "sa", "sc", "sd", "se", "sg", "si", "sk", "sl", "sm", "sn", "so", "sq", "sr", "ss", "st", "su", "sv", "sw",
        "ta", "te", "tg", "th", "ti", "tk", "tl", "tn", "to", "tr", "ts", "tt", "tw", "ty",
        "ug", "uk", "ur", "uz",
        "ve", "vi", "vo",
        "wa", "wo",
        "xh",
        "yi", "yo",
        "za", "zh", "zu",

        // ISO 639-2/T (3-letter) — common ones
        "eng", "fre", "fra", "ger", "deu", "spa", "ita", "por", "rus", "jpn",
        "kor", "chi", "zho", "ara", "hin", "tur", "pol", "nld", "dut", "swe",
        "nor", "dan", "fin", "ces", "cze", "hun", "rum", "ron", "bul", "hrv",
        "srp", "slv", "slk", "slo", "ukr", "heb", "tha", "vie", "ind", "may",
        "msa", "fil", "tgl", "kat", "geo", "arm", "hye", "per", "fas", "gre",
        "ell", "baq", "eus", "cat", "glg", "ice", "isl", "lav", "lit", "est",
        "alb", "sqi", "mac", "mkd", "bos", "mlt", "gle", "wel", "cym",
        "lat", "mul", "und", "unk", "zxx", "mis", "qaa"
    ]

    /// Language names for title-based detection.
    static let languageNames: Set<String> = [
        "english", "french", "german", "spanish", "italian", "portuguese",
        "russian", "japanese", "korean", "chinese", "mandarin", "cantonese",
        "arabic", "hindi", "turkish", "polish", "dutch", "swedish",
        "norwegian", "danish", "finnish", "czech", "hungarian", "romanian",
        "bulgarian", "croatian", "serbian", "slovenian", "slovak", "ukrainian",
        "hebrew", "thai", "vietnamese", "indonesian", "malay", "filipino",
        "tagalog", "georgian", "armenian", "persian", "farsi", "greek",
        "basque", "catalan", "galician", "icelandic", "latvian", "lithuanian",
        "estonian", "albanian", "macedonian", "bosnian", "maltese", "irish",
        "welsh", "latin", "brazilian", "castilian"
    ]

    /// Map of English-equivalent language codes.
    static let englishCodes: Set<String> = ["en", "eng", "english"]

    /// Check if a language code is recognized.
    static func isRecognizedCode(_ code: String) -> Bool {
        recognizedCodes.contains(code.lowercased())
    }

    /// Check if a title string contains a language name.
    static func titleContainsLanguageName(_ title: String) -> Bool {
        let lower = title.lowercased()
        return languageNames.contains { lower.contains($0) }
    }

    /// Check if a language code represents English.
    static func isEnglish(_ code: String?) -> Bool {
        guard let code = code?.lowercased() else { return false }
        return englishCodes.contains(code)
    }

    /// Get a display name for a language code.
    static func displayName(for code: String) -> String {
        let locale = Locale.current
        if let name = locale.localizedString(forLanguageCode: code) {
            return name
        }
        return code.uppercased()
    }

    /// Normalize various language code formats to ISO 639-2/T (3-letter).
    static func normalize(_ code: String) -> String {
        let lower = code.lowercased().trimmingCharacters(in: .whitespaces)

        // Already 3-letter
        if lower.count == 3 && recognizedCodes.contains(lower) {
            return lower
        }

        // 2-letter to 3-letter mapping for common languages
        let twoToThree: [String: String] = [
            "en": "eng", "fr": "fre", "de": "ger", "es": "spa",
            "it": "ita", "pt": "por", "ru": "rus", "ja": "jpn",
            "ko": "kor", "zh": "chi", "ar": "ara", "hi": "hin",
            "tr": "tur", "pl": "pol", "nl": "dut", "sv": "swe",
            "no": "nor", "da": "dan", "fi": "fin", "cs": "cze",
            "hu": "hun", "ro": "rum", "bg": "bul", "hr": "hrv",
            "sr": "srp", "sl": "slv", "sk": "slo", "uk": "ukr",
            "he": "heb", "th": "tha", "vi": "vie", "id": "ind",
            "ms": "may", "ka": "geo", "el": "gre", "la": "lat"
        ]

        if let three = twoToThree[lower] {
            return three
        }

        return lower
    }
}
