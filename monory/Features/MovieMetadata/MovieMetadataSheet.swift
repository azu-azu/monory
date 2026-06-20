import SwiftUI
import SwiftData

struct MovieMetadataSheet: View {
    let log: MovieLog

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var vm: MovieMetadataViewModel?
    @State private var showCulturalImpactEdit = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    sheetContent(vm: vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(log.movieTitle.isEmpty ? "作品詳細" : log.movieTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let vm {
                        Button {
                            Task { await vm.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(vm.isLoading)
                    }
                }
            }
        }
        .task {
            guard vm == nil else { return }
            let v = MovieMetadataViewModel(log: log, context: context)
            vm = v
            await v.load()
            await v.loadAwards()
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func sheetContent(vm: MovieMetadataViewModel) -> some View {
        List {
            posterTitleSection

            scoreSection(vm: vm)

            if let error = vm.refreshError {
                Section {
                    Label("更新失敗: \(error.localizedDescription)", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            detailsSection(vm: vm)

            crewSection(vm: vm)

            watchProvidersSection(vm: vm)

            awardsSection(vm: vm)

            culturalImpactSection(vm: vm)

            attributionSection
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var posterTitleSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                if let data = log.moviePosterData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 90)
                        .clipped()
                        .cornerRadius(6)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.movieTitle.isEmpty ? "—" : log.movieTitle)
                        .font(.headline)
                    if let originalTitle = log.movieOriginalTitle {
                        Text(originalTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let year = log.movieReleaseYear {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func scoreSection(vm: MovieMetadataViewModel) -> some View {
        Section("TMDB スコア") {
            if vm.isLoading && vm.metadata == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let avg = vm.voteAverage {
                LabeledContent("スコア", value: String(format: "%.1f / 10", avg))
                if let count = vm.voteCount {
                    LabeledContent("投票数", value: "\(count.formatted()) 票")
                }
            } else if let error = vm.loadError {
                Label(error.localizedDescription, systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("データなし")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func detailsSection(vm: MovieMetadataViewModel) -> some View {
        let genres = vm.genres
        let runtime = vm.runtimeMinutes
        let cert = vm.jpCertification
        let rev = vm.revenue
        if !genres.isEmpty || runtime != nil || cert != nil || rev != nil {
            Section("作品情報") {
                if let runtime {
                    LabeledContent("上映時間", value: "\(runtime) 分")
                }
                if !genres.isEmpty {
                    LabeledContent("ジャンル", value: genres.joined(separator: " / "))
                }
                if let cert {
                    LabeledContent("年齢区分（JP）", value: cert)
                }
                if let rev {
                    LabeledContent("興行収入", value: rev.formatted(.currency(code: "USD").presentation(.narrow)))
                }
            }
        }
    }

    @ViewBuilder
    private func watchProvidersSection(vm: MovieMetadataViewModel) -> some View {
        let providers = vm.watchProviders
        if !providers.isEmpty {
            Section {
                providerRows(providers, type: .subscription, label: "サブスクリプション")
                providerRows(providers, type: .free,         label: "無料")
                providerRows(providers, type: .ads,          label: "広告付き無料")
                providerRows(providers, type: .rent,         label: "レンタル")
                providerRows(providers, type: .buy,          label: "購入")
            } header: {
                Text("現在の配信情報（JP）")
            } footer: {
                Text("配信状況は変わる場合があります。鑑賞時のサービスはメディア欄に記録してください。")
            }
        }
    }

    @ViewBuilder
    private func providerRows(_ all: [WatchProvider], type: WatchProviderType, label: String) -> some View {
        let filtered = all.filter { $0.type == type }
            .sorted(by: { $0.displayPriority < $1.displayPriority })
        if !filtered.isEmpty {
            LabeledContent(label, value: filtered.map(\.providerName).joined(separator: "、"))
        }
    }

    @ViewBuilder
    private func crewSection(vm: MovieMetadataViewModel) -> some View {
        let director = vm.director
        let cast = vm.cast
        if director != nil || !cast.isEmpty {
            Section("スタッフ・キャスト") {
                if let director {
                    LabeledContent("監督", value: director)
                }
                if !cast.isEmpty {
                    LabeledContent("キャスト") {
                        Text(cast.joined(separator: "\n"))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func awardsSection(vm: MovieMetadataViewModel) -> some View {
        Section("受賞歴") {
            if vm.awardsLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if vm.awardsError != nil {
                Text("受賞歴データを取得できませんでした")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if vm.awards.isEmpty {
                Text("受賞歴データなし")
                    .foregroundStyle(.secondary)
            } else {
                awardRows(vm.awards.filter { $0.type == .won },       label: "受賞")
                awardRows(vm.awards.filter { $0.type == .nominated }, label: "ノミネート")
            }
        }
    }

    @ViewBuilder
    private func awardRows(_ awards: [WikidataAward], label: String) -> some View {
        ForEach(awards) { award in
            HStack(alignment: .top, spacing: 8) {
                Text(award.awardName)
                    .font(.subheadline)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(label == "受賞" ? Color.orange : Color.secondary)
                    if let year = award.year {
                        Text(String(year))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func culturalImpactSection(vm: MovieMetadataViewModel) -> some View {
        Section {
            let hasNote = !vm.culturalImpactNote.isEmpty
            let hasSources = !vm.culturalImpactSources.isEmpty
            if hasNote {
                Text(vm.culturalImpactNote)
                    .font(.body)
            }
            if hasSources {
                ForEach(vm.culturalImpactSources, id: \.absoluteString) { url in
                    Link(url.absoluteString, destination: url)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            if !hasNote && !hasSources {
                Text("未記録")
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("文化的インパクト")
                Spacer()
                Button("編集") { showCulturalImpactEdit = true }
                    .font(.caption)
            }
        }
        .sheet(isPresented: $showCulturalImpactEdit) {
            CulturalImpactEditView(vm: vm)
        }
    }

    @ViewBuilder
    private var attributionSection: some View {
        Section {
            // TMDB attribution requirement:
            // https://www.themoviedb.org/about/logos-attribution
            // TMDBLogo.imageset に公式ロゴ PNG を配置すること（現在は placeholder）
            HStack(spacing: 8) {
                if UIImage(named: "TMDBLogo") != nil {
                    Image("TMDBLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 18)
                }
                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
