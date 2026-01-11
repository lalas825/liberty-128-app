enum RiskLevel {
  Low,
  Medium,
  High,
}

class N400Term {
  final String id;
  final String term;
  final String legalDefinition;
  final String simpleExplanation;
  final RiskLevel riskLevel;

  const N400Term({
    required this.id,
    required this.term,
    required this.legalDefinition,
    required this.simpleExplanation,
    required this.riskLevel,
  });

  factory N400Term.fromJson(Map<String, dynamic> json) {
    return N400Term(
      id: json['id'] as String,
      term: json['term'] as String,
      legalDefinition: json['legalDefinition'] as String,
      simpleExplanation: json['simpleExplanation'] as String,
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['riskLevel'],
        orElse: () => RiskLevel.Medium,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'term': term,
      'legalDefinition': legalDefinition,
      'simpleExplanation': simpleExplanation,
      'riskLevel': riskLevel.toString().split('.').last,
    };
  }
}
