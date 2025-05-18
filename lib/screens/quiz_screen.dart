import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/question_model.dart';

class QuizScreen extends StatefulWidget {
  final String level;

  const QuizScreen({super.key, required this.level});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question> questions = [];
  int currentIndex = 0;
  int score = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('questions')
              .where('level', isEqualTo: widget.level.toLowerCase())
              .get();

      if (snapshot.docs.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      questions =
          snapshot.docs
              .map((doc) => Question.fromMap(doc.id, doc.data()))
              .toList();

      setState(() => isLoading = false);
    } catch (e) {
      print("Error loading questions: $e");
      setState(() => isLoading = false);
    }
  }

  void _answerQuestion(String selected) {
    final correct = questions[currentIndex].answer;

    if (selected == correct) {
      score++;
      _showResultDialog(true);
    } else {
      _showResultDialog(false);
    }
  }

  void _showResultDialog(bool isCorrect) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(isCorrect ? "Correct!" : "Wrong"),
            content: Text(
              isCorrect
                  ? "Nice job!"
                  : "Correct answer: ${questions[currentIndex].answer}",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _nextQuestion();
                },
                child: const Text("Next"),
              ),
            ],
          ),
    );
  }

  void _nextQuestion() {
    if (currentIndex < questions.length - 1) {
      setState(() => currentIndex++);
    } else {
      _showFinalScore();
    }
  }

  void _showFinalScore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance.collection('user_scores').add({
        'userId': user.uid,
        'level': widget.level,
        'score': score,
        'total': questions.length,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("Quiz Complete!"),
            content: Text("Your score: $score/${questions.length}"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    currentIndex = 0;
                    score = 0;
                  });
                },
                child: const Text("Retry Level"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("Back to Levels"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("No Questions")),
        body: const Center(
          child: Text(
            "No questions found for this level.",
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final question = questions[currentIndex];
    final total = questions.length;
    final progress = (currentIndex + 1) / total;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldLeave = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("Exit Quiz?"),
                content: const Text(
                  "Are you sure you want to go back? Your progress will be lost.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Exit"),
                  ),
                ],
              ),
        );

        if (shouldLeave == true) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text("Level: ${widget.level.toUpperCase()}")),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Indicator
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.deepPurple.shade100,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),

              // Question Counter
              Text(
                "Question ${currentIndex + 1} of $total",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 20),

              // Question Text
              Text(
                question.question,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              // Option Buttons
              ...question.options.map((option) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () => _answerQuestion(option),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepPurple.shade100,
                      foregroundColor: Colors.deepPurple.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(option, style: const TextStyle(fontSize: 16)),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
