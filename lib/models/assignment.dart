class Assignment {
  final String freelancerId;
  final String freelancerName;
  final List<String> tasks;
  final DateTime assignedDate;
  final String? role;
  final String? email;
  final String? phone;

  Assignment({
    required this.freelancerId,
    required this.freelancerName,
    required this.tasks,
    required this.assignedDate,
    this.role,
    this.email,
    this.phone,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      freelancerId: json['freelancer_id'] as String,
      freelancerName: json['freelancer_name'] as String,
      tasks: List<String>.from(json['tasks'] ?? []),
      assignedDate: DateTime.parse(json['assigned_date'] as String),
      role: json['role'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'freelancer_id': freelancerId,
      'freelancer_name': freelancerName,
      'tasks': tasks,
      'assigned_date': assignedDate.toIso8601String(),
      'role': role,
      'email': email,
      'phone': phone,
    };
  }

  Assignment copyWith({
    String? freelancerId,
    String? freelancerName,
    List<String>? tasks,
    DateTime? assignedDate,
    String? role,
    String? email,
    String? phone,
  }) {
    return Assignment(
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      tasks: tasks ?? this.tasks,
      assignedDate: assignedDate ?? this.assignedDate,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}

class PremiseAssignment {
  final String premiseId;
  final String premiseName;
  final Map<String, Assignment> assignments;
  final DateTime? lastUpdated;

  PremiseAssignment({
    required this.premiseId,
    required this.premiseName,
    required this.assignments,
    this.lastUpdated,
  });

  factory PremiseAssignment.fromJson(Map<String, dynamic> json) {
    final assignmentsMap = <String, Assignment>{};
    final assignmentsJson = json['assignments'] as Map<String, dynamic>? ?? {};
    
    assignmentsJson.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        assignmentsMap[key] = Assignment.fromJson(value);
      }
    });

    return PremiseAssignment(
      premiseId: json['premise_id'] as String,
      premiseName: json['premise_name'] as String,
      assignments: assignmentsMap,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final assignmentsJson = <String, dynamic>{};
    assignments.forEach((key, value) {
      assignmentsJson[key] = value.toJson();
    });

    return {
      'premise_id': premiseId,
      'premise_name': premiseName,
      'assignments': assignmentsJson,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  bool get hasAssignments => assignments.isNotEmpty;
  
  int get assignmentCount => assignments.length;
  
  List<Assignment> get assignmentsList => assignments.values.toList();
  
  List<String> get assignedFreelancerIds => assignments.keys.toList();
  
  List<String> get assignedFreelancerNames => 
      assignments.values.map((a) => a.freelancerName).toList();

  Assignment? getAssignmentForFreelancer(String freelancerId) {
    return assignments[freelancerId];
  }

  bool isFreelancerAssigned(String freelancerId) {
    return assignments.containsKey(freelancerId);
  }

  PremiseAssignment copyWith({
    String? premiseId,
    String? premiseName,
    Map<String, Assignment>? assignments,
    DateTime? lastUpdated,
  }) {
    return PremiseAssignment(
      premiseId: premiseId ?? this.premiseId,
      premiseName: premiseName ?? this.premiseName,
      assignments: assignments ?? this.assignments,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  PremiseAssignment addAssignment(String freelancerId, Assignment assignment) {
    final newAssignments = Map<String, Assignment>.from(assignments);
    newAssignments[freelancerId] = assignment;
    return copyWith(
      assignments: newAssignments,
      lastUpdated: DateTime.now(),
    );
  }

  PremiseAssignment removeAssignment(String freelancerId) {
    final newAssignments = Map<String, Assignment>.from(assignments);
    newAssignments.remove(freelancerId);
    return copyWith(
      assignments: newAssignments,
      lastUpdated: DateTime.now(),
    );
  }
}

class AssignmentOverview {
  final String contractorId;
  final List<PremiseAssignment> premiseAssignments;
  final int totalPremises;
  final int assignedPremises;
  final int totalAssignments;
  final Map<String, int> taskTypeCount;

  AssignmentOverview({
    required this.contractorId,
    required this.premiseAssignments,
    required this.totalPremises,
    required this.assignedPremises,
    required this.totalAssignments,
    required this.taskTypeCount,
  });

  factory AssignmentOverview.fromPremiseAssignments(
    String contractorId,
    List<PremiseAssignment> assignments,
    int totalPremises,
  ) {
    final taskTypeCount = <String, int>{};
    int totalAssignments = 0;

    for (final premiseAssignment in assignments) {
      totalAssignments += premiseAssignment.assignmentCount;
      
      for (final assignment in premiseAssignment.assignmentsList) {
        for (final task in assignment.tasks) {
          taskTypeCount[task.toLowerCase()] = (taskTypeCount[task.toLowerCase()] ?? 0) + 1;
        }
      }
    }

    return AssignmentOverview(
      contractorId: contractorId,
      premiseAssignments: assignments,
      totalPremises: totalPremises,
      assignedPremises: assignments.length,
      totalAssignments: totalAssignments,
      taskTypeCount: taskTypeCount,
    );
  }

  double get assignmentPercentage => 
      totalPremises > 0 ? (assignedPremises / totalPremises) * 100 : 0.0;

  List<String> get mostCommonTasks {
    final sortedTasks = taskTypeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedTasks.take(5).map((e) => e.key).toList();
  }

  Map<String, int> get freelancerWorkload {
    final workload = <String, int>{};
    
    for (final premiseAssignment in premiseAssignments) {
      for (final assignment in premiseAssignment.assignmentsList) {
        workload[assignment.freelancerName] = 
            (workload[assignment.freelancerName] ?? 0) + 1;
      }
    }
    
    return workload;
  }
}
