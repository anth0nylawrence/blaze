import XCTest
@testable import Blaze

@MainActor
final class AskUserQuestionPromptTests: XCTestCase {
    func testMultiSelectTrueProducesMultiSelectPrompt() {
        let input = """
        {"questions":[{"question":"Pick two","header":"Options","options":[{"id":"opt-a","label":"A"},{"label":"B"}],"multiSelect":true}]}
        """
        let appState = AppState()

        let prompts = appState.parseAskUserQuestion(
            toolCallId: "toolu_1",
            input: input,
            timestamp: Date()
        )

        XCTAssertEqual(prompts.count, 1)
        guard let prompt = prompts.first else {
            XCTFail("Expected prompt to parse")
            return
        }

        XCTAssertEqual(prompt.responseType, .multiSelect)
        XCTAssertEqual(prompt.options.count, 2)
        XCTAssertEqual(prompt.options[0].id, "opt-a")
        XCTAssertEqual(prompt.options[1].id, "B")
    }

    func testMultiSelectStringTrueIsAccepted() {
        let input = """
        {"questions":[{"question":"Pick","options":[{"label":"A"},{"label":"B"}],"multi_select":"true"}]}
        """
        let appState = AppState()

        let prompts = appState.parseAskUserQuestion(
            toolCallId: "toolu_2",
            input: input,
            timestamp: Date()
        )

        XCTAssertEqual(prompts.count, 1)
        guard let prompt = prompts.first else {
            XCTFail("Expected prompt to parse")
            return
        }

        XCTAssertEqual(prompt.responseType, .multiSelect)
    }

    func testMultipleQuestionsCreateMultiplePrompts() {
        let input = """
        {"questions":[{"question":"Pick one","options":[{"label":"A"},{"label":"B"}]},{"question":"Pick two","options":[{"label":"C"},{"label":"D"}],"multiSelect":true}]}
        """
        let appState = AppState()

        let prompts = appState.parseAskUserQuestion(
            toolCallId: "toolu_3",
            input: input,
            timestamp: Date()
        )

        XCTAssertEqual(prompts.count, 2)
        XCTAssertEqual(prompts[0].responseType, .singleSelect)
        XCTAssertEqual(prompts[1].responseType, .multiSelect)
        XCTAssertNotEqual(prompts[0].id, prompts[1].id)
        XCTAssertEqual(prompts[0].promptIndex, 1)
        XCTAssertEqual(prompts[0].promptCount, 2)
        XCTAssertEqual(prompts[1].promptIndex, 2)
        XCTAssertEqual(prompts[1].promptCount, 2)
    }
}
