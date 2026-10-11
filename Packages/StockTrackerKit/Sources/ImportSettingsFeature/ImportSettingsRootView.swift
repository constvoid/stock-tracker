import Application
import DesignSystem
import Domain
import SwiftUI
import UniformTypeIdentifiers

public struct ImportSettingsRootView: View {
    @Bindable private var viewModel: ImportSettingsViewModel
    private let onSelectAccount: (AccountID) -> Void
    private let onOpenCarGlance: (() -> Void)?
    @State private var isImporterPresented = false

    public init(
        viewModel: ImportSettingsViewModel,
        onSelectAccount: @escaping (AccountID) -> Void = { _ in },
        onOpenCarGlance: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSelectAccount = onSelectAccount
        self.onOpenCarGlance = onOpenCarGlance
    }

    public var body: some View {
        NavigationStack {
            List {
                importSection
                accountsSection
                dataStatusSection
            }
            .navigationTitle("Settings")
            .task { await viewModel.load() }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await viewModel.importFiles(urls) }
                case .failure:
                    viewModel.reportFileSelectionFailure()
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.phase == .preview || viewModel.phase == .committing },
                set: { if !$0 { viewModel.cancelPreview() } }
            )) {
                ImportPreviewSheet(viewModel: viewModel)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.phase == .result },
                set: { if !$0 { viewModel.finishResult() } }
            )) {
                ImportResultSheet(viewModel: viewModel)
            }
        }
        .accessibilityIdentifier("importSettings.root")
    }

    @ViewBuilder
    private var importSection: some View {
        Section("Import") {
            Button {
                isImporterPresented = true
            } label: {
                Label("Import brokerage files", systemImage: "square.and.arrow.down")
            }
            .disabled(viewModel.phase == .parsing || viewModel.phase == .committing)

            if viewModel.phase == .parsing {
                ProgressView("Parsing…")
            }

            if let summaries = viewModel.settings?.lastImportSummaries, !summaries.isEmpty {
                ForEach(summaries, id: \.self) { summary in
                    Text(summary)
                        .font(PortfolioTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(PortfolioTypography.caption)
                    .foregroundStyle(PortfolioColor.loss)
            }

            Text("One complete file per brokerage. Raw files are not kept after import.")
                .font(PortfolioTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var accountsSection: some View {
        Section("Accounts") {
            if let accounts = viewModel.settings?.accounts, !accounts.isEmpty {
                ForEach(accounts) { account in
                    VStack(alignment: .leading, spacing: PortfolioSpacing.sm) {
                        HStack {
                            Button {
                                onSelectAccount(account.accountID)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.displayName)
                                        .font(PortfolioTypography.rowTitle)
                                    Text(account.brokerageName)
                                        .font(PortfolioTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Toggle(
                                "Enabled",
                                isOn: Binding(
                                    get: { account.isEnabled },
                                    set: { newValue in
                                        Task { await viewModel.setEnabled(accountID: account.accountID, enabled: newValue) }
                                    }
                                )
                            )
                            .labelsHidden()
                            .accessibilityLabel("Enabled for \(account.displayName)")
                        }

                        HStack {
                            Text(MoneyFormatting.currency(account.totalValue.amount))
                                .font(PortfolioTypography.secondary)
                            if account.isStale {
                                Text("Stale")
                                    .font(PortfolioTypography.caption)
                                    .foregroundStyle(PortfolioColor.stale)
                            }
                        }

                        if account.isStale {
                            HStack {
                                Button("Keep") {
                                    Task { await viewModel.resolve(accountID: account.accountID, action: .keep) }
                                }
                                Button("Hide") {
                                    Task { await viewModel.resolve(accountID: account.accountID, action: .hide) }
                                }
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.resolve(accountID: account.accountID, action: .delete) }
                                }
                            }
                            .font(PortfolioTypography.caption)
                        }
                    }
                    .padding(.vertical, PortfolioSpacing.xs)
                }
            } else {
                Text("No accounts imported yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var dataStatusSection: some View {
        Section("Driving") {
            if let onOpenCarGlance {
                Button {
                    onOpenCarGlance()
                } label: {
                    Label("Open Car Glance", systemImage: "car.side")
                }
                .accessibilityHint("Shows a large-type portfolio summary for a phone mount")
            }
            Text("Car Glance is an iPhone surface. It does not require CarPlay.")
                .font(PortfolioTypography.caption)
                .foregroundStyle(.secondary)
        }

        Section("Data status") {
            Text("Prices refresh on pull and when the app becomes active.")
            Text("Storage: local-only on this device.")
            Text("Raw brokerage files are discarded after parsing.")
        }
        .font(PortfolioTypography.caption)
        .foregroundStyle(.secondary)
    }
}

private struct ImportPreviewSheet: View {
    @Bindable var viewModel: ImportSettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.previews.enumerated()), id: \.offset) { _, preview in
                    Section(preview.batch.brokerage.displayName) {
                        Text("Parser: \(preview.batch.source.parserIdentifier)")
                            .font(PortfolioTypography.caption)
                        if let asOf = preview.batch.source.providerTimestamp {
                            Text("As of \(asOf.formatted(date: .abbreviated, time: .shortened))")
                                .font(PortfolioTypography.caption)
                        }
                        ForEach(preview.accounts, id: \.sourceAccountKey.externalReference) { account in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(account.displayName)
                                        .font(PortfolioTypography.rowTitle)
                                    Spacer()
                                    Text(account.willCommit ? "Will commit" : "Blocked")
                                        .font(PortfolioTypography.caption)
                                        .foregroundStyle(account.willCommit ? PortfolioColor.gain : PortfolioColor.loss)
                                }
                                Text("\(account.disposition.rawValue) · \(account.positionCount) positions · cash \(MoneyFormatting.currency(account.cash.amount))")
                                    .font(PortfolioTypography.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(account.issues.prefix(3), id: \.code) { issue in
                                    Text("\(issue.severity.rawValue): \(issue.redactedMessage)")
                                        .font(PortfolioTypography.caption)
                                        .foregroundStyle(issue.severity == .error ? PortfolioColor.loss : PortfolioColor.warning)
                                }
                            }
                        }
                        ForEach(preview.staleAccounts, id: \.sourceAccountKey.externalReference) { stale in
                            Text("Will mark stale: \(stale.displayName)")
                                .font(PortfolioTypography.caption)
                                .foregroundStyle(PortfolioColor.stale)
                        }
                    }
                }
            }
            .navigationTitle("Import preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancelPreview() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        Task { await viewModel.confirmImport() }
                    }
                    .disabled(viewModel.phase == .committing || !viewModel.previews.contains { preview in
                        preview.accounts.contains(where: \.willCommit)
                    })
                }
            }
            .overlay {
                if viewModel.phase == .committing {
                    ProgressView("Committing…")
                        .padding()
                        .background(.ultraThinMaterial)
                }
            }
        }
    }
}

private struct ImportResultSheet: View {
    @Bindable var viewModel: ImportSettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                if let result = viewModel.commitResult {
                    Section("Committed") {
                        let committed = result.accountResults.filter(\.committed)
                        if committed.isEmpty {
                            Text("No accounts committed.")
                        } else {
                            ForEach(committed, id: \.sourceAccountKey.externalReference) { row in
                                Text(row.sourceAccountKey.externalReference)
                            }
                        }
                    }
                    Section("Unchanged due to errors") {
                        let blocked = result.accountResults.filter { !$0.committed }
                        if blocked.isEmpty {
                            Text("None")
                        } else {
                            ForEach(blocked, id: \.sourceAccountKey.externalReference) { row in
                                Text(row.sourceAccountKey.externalReference)
                            }
                        }
                    }
                    Section("Stale accounts") {
                        if result.staleAccountIDs.isEmpty {
                            Text("None")
                        } else {
                            Text("\(result.staleAccountIDs.count) account(s) marked stale. Review in Accounts.")
                        }
                    }
                }
            }
            .navigationTitle("Import result")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.finishResult() }
                }
            }
        }
    }
}
