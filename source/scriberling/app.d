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
			auto lexer = SDFLexer(source, Location(args[2], 1, 1));
			bool hasError = false;

			foreach (token; lexer) {
				if (token.type == SDFTokenType.error) {
					hasError = true;
				}
				writeln(token);
			}

			return (hasError) ? 1 : 0;
		}

	case "--parse": {
			import std.file : readText;
			import scriberling.formats.sdf.lexer;
			import scriberling.formats.sdf.parser;
			import scriberling.types;

			const source = readText(args[2]);
			auto lexer = SDFLexer(source, Location(args[2], 1, 1));
			try {
				auto doc = parseSDF(lexer);
			} catch (Exception ex) {
				stderr.printException(ex);
				return 1;
			}
			return 0;
		}

	case "--process": {
			import std.file : readText;
			import scriberling.formats.sdf.lexer;
			import scriberling.formats.sdf.parser;
			import scriberling.siteconfig;
			import scriberling.types;
			import scriberling.dom;

			static final class FileSink : Sink {
				import std.stdio : File, write;

				private {
					File _file;
				}

				public this(File file) {
					_file = file;
				}

				void put(char data) {
					_file.write(data);
				}

				void put(hstring data) {
					_file.write(data);
				}
			}

			const source = readText(args[2]);
			auto lexer = SDFLexer(source, Location(args[2], 1, 1));
			try {
				auto doc = parseSDF(lexer);
				doc.compile(defaultSiteConfig);
				doc.toHTML(new FileSink(stdout));
				stdout.writeln();
			} catch (Exception ex) {
				stderr.printException(ex);
				return 1;
			}
			return 0;
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

void printException(File sink, Exception ex) @trusted {
	sink.writeln(ex);
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
