import 'dart:js_interop';

@JS('window.print')
external void _printWindow();

void printCurrentPage() {
  _printWindow();
}
