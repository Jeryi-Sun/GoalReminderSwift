import CoreML
import Foundation

protocol GoalInsightProviding {
    func scoreGoalPriority(text: String) -> Double
}

final class GoalInsightEngine: GoalInsightProviding {
    private let model: MLModel?

    init(compiledModelURL: URL? = nil) {
        if let compiledModelURL {
            self.model = try? MLModel(contentsOf: compiledModelURL)
        } else {
            self.model = nil
        }
    }

    func scoreGoalPriority(text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 0
        }

        // Placeholder: model schema is unknown now, so fallback to deterministic scoring.
        // Once a Core ML model is provided, replace with model-specific feature mapping.
        _ = model
        let lengthFactor = min(Double(trimmed.count) / 40.0, 1.0)
        return max(0.2, lengthFactor)
    }
}
