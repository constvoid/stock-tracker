import Application
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class ImportSettingsViewModel {
    public enum Phase: Equatable {
        case idle
        case parsing
        case preview
        case committing
        case result
    }

    public private(set) var settings: SettingsReadModel?
    public private(set) var phase: Phase = .idle
    public private(set) var previews: [BrokerageImportPreview] = []
    public private(set) var commitResult: ImportCommitResult?
    public private(set) var errorMessage: String?

    private let getSettings: GetSettingsAccounts
    private let importing: any BrokerageImporting
    private let previewImports: PreviewBrokerageImports
    private let commitImports: CommitAccountImports
    private let setVisibility: SetAccountVisibility
    private let resolveStale: ResolveStaleAccount

    public init(
        getSettings: GetSettingsAccounts,
        importing: any BrokerageImporting,
        previewImports: PreviewBrokerageImports,
        commitImports: CommitAccountImports,
        setVisibility: SetAccountVisibility,
        resolveStale: ResolveStaleAccount
    ) {
        self.getSettings = getSettings
        self.importing = importing
        self.previewImports = previewImports
        self.commitImports = commitImports
        self.setVisibility = setVisibility
        self.resolveStale = resolveStale
    }

    public func load() async {
        errorMessage = nil
        do {
            settings = try await getSettings()
        } catch {
            errorMessage = "Couldn't load settings."
        }
    }

    public func reportFileSelectionFailure() {
        errorMessage = "File selection failed."
    }

    public func importFiles(_ urls: [URL]) async {
        phase = .parsing
        errorMessage = nil
        defer {
            if phase == .parsing { phase = .idle }
        }
        var accessed: [URL] = []
        for url in urls where url.startAccessingSecurityScopedResource() {
            accessed.append(url)
        }
        defer {
            for url in accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let batches = try await importing.inspect(files: urls)
            previews = try await previewImports(batches)
            phase = .preview
        } catch {
            errorMessage = "Couldn't parse selected files."
            phase = .idle
        }
    }

    public func confirmImport() async {
        phase = .committing
        do {
            let batches = previews.map(\.batch)
            commitResult = try await commitImports(batches)
            phase = .result
            await load()
        } catch {
            errorMessage = "Import commit failed."
            phase = .preview
        }
    }

    public func cancelPreview() {
        previews = []
        phase = .idle
    }

    public func finishResult() {
        commitResult = nil
        previews = []
        phase = .idle
    }

    public func setEnabled(accountID: AccountID, enabled: Bool) async {
        do {
            try await setVisibility(accountID: accountID, enabled: enabled)
            await load()
        } catch {
            errorMessage = "Couldn't update visibility."
        }
    }

    public func resolve(accountID: AccountID, action: StaleAccountAction) async {
        do {
            try await resolveStale(accountID: accountID, action: action)
            await load()
        } catch {
            errorMessage = "Couldn't resolve stale account."
        }
    }
}
