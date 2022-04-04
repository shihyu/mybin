import 'dart:io';
import 'dart:convert';
import 'dart:async';

class Code {
  // collects all the imports
  List<String> imports = [];

  //
  List<String> functions = [];

  //
  List<String> statements = [];

  // stores all the lines imported so far
  List<String> lines = [];

  // generate code
  String text = "";

  //
  bool insideFunction = false;

  Code() {
    this.imports.add("import 'dart:io'");
  }

  /**
   *
   */
  bool analyzeLine(String line) {
    lines.add(line);

    if(line.startsWith('import ')) {
      this.imports.add(line);
      return true;

    } else if (line.isNotEmpty) {
      this.statements.add(line);

      return this.insideFunction;
    }
    return true;
  }

  /**
   *
   */
  String generateText() {

    // convert imports to text
    String importsText = '';
    this.imports.forEach((importLine) => importsText += importLine + ';\n');

    String statementsText = '';
    this.statements.forEach((statementLine) => statementsText += '\t' + statementLine + ';\n');

    this.text = importsText +
      "\nmain() async {\n\t" +
        statementsText +
        "\n}\n";

    return this.text;
  }
}


execute(Code newCode) async {

  final File file = new File('temp.dart');
  var output = file.openWrite();

  output.write(newCode.generateText());
  output.close();

  ProcessResult pr = await Process.run('dart', ['temp.dart']);
  print(pr.exitCode);
  print(pr.stdout);
  print(pr.stderr);
}

main(List<String> arguments) async {

  var newCode = new Code();
  String line = '';
  bool notInstantExecute = true;
  print(' ===============================');
  print('||          Dart REPL          ||');
  print(' ===============================');
  print('type "." to exit \n');
  do {
    stdout.write('dart>');
    line = stdin.readLineSync()!;

    if (line != '.') {
      notInstantExecute = newCode.analyzeLine(line);
    } else {
      notInstantExecute = true;
    }

    if (!notInstantExecute) {
      await execute(newCode);
    }

  } while(line != '.');

  print('Quit.');
}

