/++
	Unicode utility library
 +/
module scriberling.data.unicode;

///
static immutable replacementCharacter = '\uFFFD';

///
static immutable string replacementCharacterString = "\uFFFD";

/++
	Encodes a codepoint into a string of code units.

	Replaces invalid codepoints with the Unicode replacement character.
 +/
string encodeCodepoint(dchar codepoint) @safe pure nothrow {
	import std.utf : encode;
	import std.typecons : Yes;

	char[4] buffer;
	const n = encode!(Yes.useReplacementDchar)(buffer, codepoint);
	return buffer[0 .. n].idup;
}
