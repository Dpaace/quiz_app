class Question {
  final String id;
  final String level;
  final String question;
  final List<String> options;
  final String answer;

  Question({
    required this.id,
    required this.level,
    required this.question,
    required this.options,
    required this.answer,
  });

  factory Question.fromMap(String id, Map<String, dynamic> data) {
    return Question(
      id: id,
      level: data['level'],
      question: data['question'],
      options: List<String>.from(data['options']),
      answer: data['answer'],
    );
  }
}
