String fcfa(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b FCFA';
}

String _two(int n) => n.toString().padLeft(2, '0');

String dateFr(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

String hourFr(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String dayFr(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String dayShort(DateTime d) => '${_two(d.day)}/${_two(d.month)}';
