/++
	Scriberling command-line utility
 +/
module scriberling.app;

import std.stdio;

/// App entry point
int main(string[] args) {
	return mainImpl(args, stdin, stdout, stderr);
}

private @safe:

int mainImpl(string[] args, File stdin, File stdout, File stderr) {

	if (args.length <= 1) {
		stderr.writeln("Error: No arguments provided.\n");
		printHelp(stderr, args[0]);
		return 1;
	}

	switch (args[1]) {
	default:
		break;

	case "--help":
	case "-h":
	case "-?":
	case "/?":
		printHelp(stdout, args[0]);
		return 0;

	case "--version":
	case "-v":
		printVersion(stdout);
		return 0;

	case "--lex": {
			import std.file : readText;
			import scriberling.formats.sdf.lexer;
			import scriberling.types;

			const source = readText(args[2]);
			auto lexer = Lexer(source, Location(args[2], 1, 1));
			foreach (token; lexer){
				writeln(token);
			}
		}
	}

	if (args.length != 3) {
		const argsCount = -1 + args.length;
		stderr.writeln(
			"Error: Invalid argument count. Expected `2` (<source> <target>) but got `",
			argsCount,
			"`.",
		);

		return 1;
	}

	return 0;
}

void printHelp(File sink, string args0) {
	sink.writeln(
		"scriberling - Static Site Generator"
			~ "\n"
			~ "\nUsage:"
			~ "\n\t" ~ args0 ~ " <source-directory> <target-directory>"
	);
}

void printVersion(File sink) {
	// TODO
	sink.writeln("v0.0.0");
	assert(false, "Not implemented");
}
