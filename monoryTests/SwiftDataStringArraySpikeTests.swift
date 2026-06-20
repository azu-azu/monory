/// Phase 0 spike: SwiftData @Model が plain [String] を直接 persist できるかを検証する。
/// 成功すれば movieGenres / movieCast を [String] で直接持てる。
/// 失敗（crash / data loss）すれば comma-joined raw String に留める。
import XCTest
import SwiftData

// テスト専用の isolated @Model。production の MovieLog とは独立している。
@Model
private final class StringArraySpike {
    var tags: [String]
    init(tags: [String] = []) {
        self.tags = tags
    }
}

final class SwiftDataStringArraySpikeTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([StringArraySpike.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    @MainActor
    func testStringArrayRoundTrip() throws {
        let context = try makeContext()
        let tags = ["Action", "Drama", "Sci-Fi"]
        context.insert(StringArraySpike(tags: tags))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StringArraySpike>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].tags, tags)
    }

    @MainActor
    func testEmptyStringArray() throws {
        let context = try makeContext()
        context.insert(StringArraySpike(tags: []))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StringArraySpike>())
        XCTAssertEqual(fetched[0].tags, [])
    }

    @MainActor
    func testMultipleRecordsWithStringArrays() throws {
        let context = try makeContext()
        context.insert(StringArraySpike(tags: ["Action", "Adventure"]))
        context.insert(StringArraySpike(tags: ["Drama"]))
        context.insert(StringArraySpike(tags: []))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StringArraySpike>())
        XCTAssertEqual(fetched.count, 3)
    }

    /// [String] で comma を含む値が個別要素として正しく保持されるか。
    /// comma-joined では collision するケースを [String] 直接 persist が解決するかを確認。
    @MainActor
    func testStringArrayPreservesCommasInValues() throws {
        let context = try makeContext()
        let tags = ["LastName, FirstName", "Science Fiction", "普通の値"]
        context.insert(StringArraySpike(tags: tags))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StringArraySpike>())
        XCTAssertEqual(fetched[0].tags, tags,
            "[String] persist が comma を含む要素を正しく保持する必要がある")
    }

    @MainActor
    func testMutatingStringArrayAfterFetch() throws {
        let context = try makeContext()
        context.insert(StringArraySpike(tags: ["Action"]))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StringArraySpike>())
        fetched[0].tags.append("Drama")
        try context.save()

        let refetched = try context.fetch(FetchDescriptor<StringArraySpike>())
        XCTAssertEqual(refetched[0].tags, ["Action", "Drama"])
    }
}
