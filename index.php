<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Slackup</title>
    <link rel="stylesheet" href="css/styles.css">
    <link rel="shortcut icon" type="image/x-icon" href="images/slackup-icon.png" />
</head>
<body>
    <header>
        <div id="icon-container">
            <img src="images/slackup-icon.png" alt="Slackup" id="icon">
        </div>
        <div id="title-container">
            Slackup
        </div>
    </header>
    <main>
        <div id="icon-slider">
            <div id="icon-slide-container">
                <img src="images/slackup-icon.png" alt="Slackup" id="icon">
            </div>
            <div id="icon-slide-container">
                <img src="images/slackup-icon.png" alt="Slackup" id="icon">
            </div>
            <div id="icon-slide-container">
                <img src="images/slackup-icon.png" alt="Slackup" id="icon">
            </div>
        </div>
        <div id="sidebar">
            <div id="search-container">
                <input type="text" id="channel-search" placeholder="Filter Channels...">
                <span id="clear-search">&times;</span>
            </div>
            <div id="channels-list"></div>
        </div>
        <div id="messages">
            <div id="messages-container"></div>
            <div id="files-container"></div>
        </div>
    </main>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="js/script.js"></script>
</body>
</html>
