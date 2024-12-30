#  DSL reference

This document contains a quick reference to the `Narratore` DSL, that is, the possible commands that one can use to write a story.

### string literal

A plain string literal will simply add a message `Step` to the story. Depending on the context, some metadata can be attached to the string, for example:
- `id`: this is used to uniquely identify the message, and can be used to verify that the message was shown in the `Script`;
- `anchor`: this can only be used in the main story builder, and allows to define a story anchor, to which the story can jump;
- `tags`: this can only be used in the main story builder, and allows to attach tags to the message, that can then be read in the story `Handler`;
- `update`: this can only be used in the main story builder, and allows to update the `World` when a message is received.

 ### `DO.tell`
 
 Groups a bunch of messages together, that must be seen all at once, into a single `Step`, potentially characterized by some `tags` and an `update` call to update the `World`.

### `DO.check`

Allows to create a conditional step, by reading the current context of `Context` of the game, that contains the `World` state, the `Script` so far, and the `Generate` utility, to generate random values.

### `DO.update`

Updates the current `World` value.

### `DO.choose`

Provides choices to the player, and assigns a `Step` to each. Choices can represented by simple string literals on which the `.onSelect` method is called.

### `DO.requestText`

Requests some text to the player, by presenting an optional message, and allows to validate the entered text.

### `DO.then`

Allows to jump to a certain point in the story.

### `DO.skip`

Simply skips the step, but an `Anchor` can be attached to it, in order to define an entry point in the story.

### `DO.group`

Can be used to create an isolated slice of the story, by grouping together a bunch of messages.
