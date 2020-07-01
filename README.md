# PChat

## What is PChat

PChat is a simple, lightweight file I/O based chat solution, created to enhance user collaboration. It is written using PowerShell and designed to be easy to deploy, operate and maintain.

PChat is designed to run on a shared drive directory that users require read/write access to. Each chat room contains a backing text file in the shared directory and stores all chat history.

### Launch PChat

1. Click on the `PChat` icon shortcut to launch PChat application.

    **Note:** Please do not click on, close or engage with any of the Powershell or command line windows that flash open briefly during startup. Allow a moment for the scripts to run and the UI to load and boot.

    **Note:** You can save the `PChat` icon to your desktop for quick access.

### Select a Chat Room

1. Choose a chat room from the selection dropdown list.
2. After selection, click the `Join Room` button.
3. The new chat room will open, and you can begin collaborating.

### Create a Chat Room

1. To create a new chat room click `Create Room`.
2. A new script will run launching a separate window.
3. Type the name name of your new chat room and click `Join Room`.

    **Note:** If a unique chat room name is not entered by the user, you can still click `Join Room` and a new room will be created using a random alphanumeric string for the name.

4. The new chat room will open, and you can begin collaborating.

### Share a Screenshot

1. Join a chat room using the steps listed above.
2. Click the `Send Screenshot` button. This calls the Snipping Tool turning your screen transparent grey.
3. Click, hold and drag the cursor over a portion of the screen you want to share, then let go.
4. The screen shot will automatically send and appear in the chat window.

**Note:** To exit during screen capture mode press the `esc` key.

### Multiple Chats

1. To join multiple chat rooms, follow the above steps to launch a new instance of PChat, a seperate window will open.

### Sharing Links

When a URL is shared in PChat a hyperlink will be automatically created in the chat history window. This allows anyone to click and open links directly.

### PCHat Notifications

Notiications are sent to users if there is activity from other users in the same chat room. Notifications are visual only, audible notifications have been silenced.

#### PChat Admin Actions

1. The `GenerateShortcut.ps1` script only needs to be run a single time by PChat administrators. *Users should only launch PChat using the logo icon.*
2. Text files and chat logs with no new activity may be periodically removed from the shared drive. If there is important information stored in PChat text files, please copy to a user owned directory.
3. Please utilize PChat responsibly and respectfully. Encourage diversity, inclusion, and collaboration.
