---
doc_type: short
full_text: sources/Generate_data_for_AILANG_finetuning.md
---

# Generate Data for AILANG Finetuning

This note raises a central open question in data generation for language model fine-tuning: should the training examples be created by the model being fine-tuned (self-instruct), by a stronger teacher model, or by a combination of both?

## Key Approaches
- **Self-generated data** ([[concepts/self-instruct]]): The model generates its own examples, potentially maintaining consistency with its own style and reducing distribution mismatch. However, initial model quality limits example quality, and it may reinforce biases.
- **Teacher-generated data** ([[concepts/teacher-student-model]], [[concepts/model-distillation]]): A more capable model produces high-quality examples, guiding the student. This can help the student learn complex patterns but may lead to overfitting to the teacher's style and a lack of independent reasoning.
- **Hybrid strategies** ([[concepts/data-generation-strategies]]): Mixing self-generated and teacher-generated data could leverage the strengths of both—using a teacher for foundational knowledge and self-generation for fine-grained alignment and consolidation.

## Implications
The choice impacts convergence speed, final model performance, generalization, and the cost of data generation. The answer likely depends on model architecture, target task complexity, and the relative strength of the teacher. This note serves as a reminder that the data generation pipeline is a critical design decision in fine-tuning workflows and warrants further exploration.

## Related Concepts
- [[concepts/teacher-student-data-generation]]
- [[concepts/grpo-training-loop]]
- [[concepts/code-gen-benchmark-methodology]]
