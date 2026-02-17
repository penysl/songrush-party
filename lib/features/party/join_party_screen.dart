import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:songrush_party/features/party/party_controller.dart';

class JoinPartyScreen extends ConsumerStatefulWidget {
  const JoinPartyScreen({super.key});

  @override
  ConsumerState<JoinPartyScreen> createState() => _JoinPartyScreenState();
}

class _JoinPartyScreenState extends ConsumerState<JoinPartyScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinParty() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final player = await ref.read(partyControllerProvider.notifier).joinParty(code, name);
      
      if (player != null && mounted) {
        context.go('/lobby/${player.partyId}/${player.id}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PARTY BEITRETEN')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Dein Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                hintText: '6-stelliger Code',
                prefixIcon: Icon(Icons.numbers),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinParty,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('BEITRETEN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
