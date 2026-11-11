import 'package:flutter/material.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

/// App bar action that enters the inspect mode. Hidden when the build does
/// not include a [BugInspector].
class InspectButton extends StatelessWidget {
  const InspectButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Same as `context.read<InspectModeCubit>()`, but null outside a host.
    final modeCubit = BugInspector.maybeModeCubitOf(context);
    if (modeCubit == null) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: modeCubit.enable,
      icon: const Icon(Icons.bug_report_outlined),
      label: const Text('Inspect'),
    );
  }
}
