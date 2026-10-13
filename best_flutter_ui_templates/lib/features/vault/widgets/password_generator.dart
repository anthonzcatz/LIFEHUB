import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/lifehub_theme.dart';

/// Cryptographically-secure password generator.
class PasswordGenerator {
  PasswordGenerator._();

  static String generate({
    int length = 16,
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
  }) {
    const uppers = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lowers = 'abcdefghijkmnpqrstuvwxyz';
    const nums = '23456789';
    const syms = '!@#\$%^&*()-_=+[]{}';

    var pool = '';
    if (upper) pool += uppers;
    if (lower) pool += lowers;
    if (digits) pool += nums;
    if (symbols) pool += syms;
    if (pool.isEmpty) pool = lowers + nums;

    final rand = Random.secure();
    return List.generate(length, (_) => pool[rand.nextInt(pool.length)]).join();
  }
}

/// Shows the generator sheet. Returns the generated password via
/// [onUse] callback (e.g. to prefill a vault entry form).
void showPasswordGeneratorSheet(
  BuildContext context, {
  ValueChanged<String>? onUse,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _GeneratorSheet(onUse: onUse),
  );
}

class _GeneratorSheet extends StatefulWidget {
  const _GeneratorSheet({this.onUse});

  final ValueChanged<String>? onUse;

  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  double _length = 16;
  bool _upper = true, _lower = true, _digits = true, _symbols = true;
  String _password = PasswordGenerator.generate();

  void _regenerate() => setState(() {
    _password = PasswordGenerator.generate(
      length: _length.round(),
      upper: _upper,
      lower: _lower,
      digits: _digits,
      symbols: _symbols,
    );
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Password Generator', style: LifeHubTheme.title),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LifeHubTheme.spacer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _password,
                    style: const TextStyle(
                      fontSize: 18,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _password));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _regenerate,
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Text('Length'),
              Expanded(
                child: Slider(
                  value: _length,
                  min: 8,
                  max: 32,
                  divisions: 24,
                  label: _length.round().toString(),
                  onChanged: (v) {
                    _length = v;
                    _regenerate();
                  },
                ),
              ),
              Text('${_length.round()}'),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('ABC'),
                selected: _upper,
                onSelected: (v) {
                  _upper = v;
                  _regenerate();
                },
              ),
              FilterChip(
                label: const Text('abc'),
                selected: _lower,
                onSelected: (v) {
                  _lower = v;
                  _regenerate();
                },
              ),
              FilterChip(
                label: const Text('123'),
                selected: _digits,
                onSelected: (v) {
                  _digits = v;
                  _regenerate();
                },
              ),
              FilterChip(
                label: const Text('#@!'),
                selected: _symbols,
                onSelected: (v) {
                  _symbols = v;
                  _regenerate();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.onUse != null)
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () {
                  widget.onUse!(_password);
                  Navigator.pop(context);
                },
                child: const Text('Use this password'),
              ),
            ),
        ],
      ),
    );
  }
}
