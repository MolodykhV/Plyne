import Foundation

/// A calm, non-alarming notice surfaced in the popover when a background
/// action could not complete. The product never throws an error dialog at
/// the user for something they can do nothing about in the moment.
enum PersistenceNotice: Equatable {
    /// A finished session could not be written to the local store.
    case couldNotSave

    /// The localized, observer-toned message key.
    var messageKey: LocalizedStringResource {
        switch self {
        case .couldNotSave:
            return "notice.could_not_save"
        }
    }
}
