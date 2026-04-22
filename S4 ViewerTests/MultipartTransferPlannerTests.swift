import Foundation
import Testing
@testable import S4_Viewer

struct MultipartTransferPlannerTests {
    @Test
    func plannerUsesSinglePartBelowThreshold() {
        let planner = MultipartTransferPlanner(
            multipartThreshold: 8 * 1_048_576,
            preferredPartSize: 8 * 1_048_576
        )

        let plan = planner.plan(byteCount: 4 * 1_048_576)

        #expect(!plan.isMultipart)
        #expect(plan.parts.count == 1)
        #expect(plan.parts[0].offset == 0)
        #expect(plan.parts[0].length == 4 * 1_048_576)
    }

    @Test
    func plannerBuildsExpectedMultipartRanges() {
        let planner = MultipartTransferPlanner(
            multipartThreshold: 8 * 1_048_576,
            preferredPartSize: 8 * 1_048_576
        )

        let plan = planner.plan(byteCount: 22 * 1_048_576)

        #expect(plan.isMultipart)
        #expect(plan.parts.count == 3)
        #expect(plan.parts[0].partNumber == 1)
        #expect(plan.parts[0].offset == 0)
        #expect(plan.parts[0].length == 8 * 1_048_576)
        #expect(plan.parts[1].partNumber == 2)
        #expect(plan.parts[1].offset == 8 * 1_048_576)
        #expect(plan.parts[1].length == 8 * 1_048_576)
        #expect(plan.parts[2].partNumber == 3)
        #expect(plan.parts[2].offset == 16 * 1_048_576)
        #expect(plan.parts[2].length == 6 * 1_048_576)
    }
}
