# Scriberling

Scriberling is an embeddable **static site generator** and a **template engine**.

## Example

```
/++
	This is a block comment.
 +/
h1 {
	Hello World!
}

// This is a line comment.
p {
	Lorem ipsum dolor sit amet.
}

p {
	Want to have consecutive elements?
	em {
		Don't worry, there is
		strong {- w -}hitespace control.
	}
}
```
