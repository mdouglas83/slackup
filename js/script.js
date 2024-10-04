const dataDir = './data';

let self = {};
let users = {};
let robots = {}
let channels = {};
let mpims = {};
let ims = {};
let publicChannels = {};
let channelsList = [];

const getData = async (path, node, key) => {
    try {
        const d = await $.getJSON(`${dataDir}${path}`);
        const n = node ? d[node] : d;
        if (Array.isArray(n)) return n.reduce((a, c) => {a[c[key]] = c; return a;}, {});
        return n;
    } catch(e) {
        console.error(`Error fetching data from ${dataDir}${path}:`, e);
        throw e;
    }
};

$(document).ready(async function() {

    self = await getData('/self/self.json', null, 'id');
    users = await getData('/users/users.json', null, 'id');
    channels = await getData('/shared/shared.json', null, 'id');
    mpims = await getData('/mpims/mpims.json', null, 'id');
    ims = await getData('/ims/ims.json', null, 'id');
    publicChannels = await getData('/public_channels/public_channels.json', 'channels', 'id');

    const channelsList = $('#channels-list');
    renderChannels();

    $('#channel-search').on('keyup', function() {
        const searchText = $(this).val().toLowerCase();
        filterChannels(searchText);
        toggleClearSearchIcon();
    });

    $('#clear-search').on('click', function() {
        $('#channel-search').val('');
        filterChannels('');
        toggleClearSearchIcon();
    });

    function toggleClearSearchIcon() {
        if ($('#channel-search').val()) {
            $('#clear-search').show();
        } else {
            $('#clear-search').hide();
        }
    }

    function renderChannels(searchText = '') {
        channelsList.empty();

        // shared
        channelsList.append('<div class="channels-header">Channels</div>');
        for (const [id, channel] of Object.entries(channels)) {
            if (channel.name.toLowerCase().includes(searchText)) {
                channelsList.append(`<div class="channels-link" data-id="${id}" data-type="shared">${channel.name}</div>`);
            }
        }

        // mpims
        channelsList.append('<div class="channels-header">Group Messages</div>');
        for (const [id, channel] of Object.entries(mpims)) {
            let members = [];
            channel.members.forEach(member => {
                const user = users[member];
                if (user && user.id != self.id) {
                    const userName = user.profile.real_name ? user.profile.real_name.split(' ')[0] : user.name;
                    members.push(userName);
                }
            });
            let participants = members.join(', ');
            if (participants.toLowerCase().includes(searchText)) {
                channelsList.append(`<div class="channels-link" data-id="${id}" data-type="mpims">${participants}</div>`);
            }
        }

        // ims
        channelsList.append('<div class="channels-header">Direct Messages</div>');
        for (const [id, channel] of Object.entries(ims)) {
            const user = users[channel.user];
            // const userName = user ? (user.profile.real_name ? user.profile.real_name : user.name) : `Unknown User (ID: ${channel.user})`;
            const userName = user ? (user.profile.real_name ? user.profile.real_name : user.name) : null;
            if (userName && userName.toLowerCase().includes(searchText)) {
                channelsList.append(`<div class="channels-link" data-id="${id}" data-type="ims">${userName}</div>`);
            }
        }

        // public channels
        channelsList.append('<div class="channels-header">Public Channels</div>');
        for (const [id, channel] of Object.entries(publicChannels)) {
            if (channel.name.toLowerCase().includes(searchText)) {
                channelsList.append(`<div class="channels-link" data-id="${id}" data-type="public_channels">${channel.name}</div>`);
            }
        }
    }

    // filter channels based on search text
    function filterChannels(searchText) {
        renderChannels(searchText);
    }

    // load messages when a channel is clicked
    $('#channels-list').on('click', '.channels-link', function () {
        $('.channels-link').removeClass('active');
        $(this).addClass('active');
        const channelId = $(this).data('id');
        const channelType = $(this).data('type');
        loadMessages(channelType, channelId);
    });

    // image_24 through image_512 exist for all users
    // image_1024 and image_original exist for some (1:1).
    $('#messages-container').on('click', '.user-icon', function() {
        const user = $(this).data('user');
        const image_big = users[user].profile.image_original ? 'image_original' : 'image_512';
        const ext = $(this).data('ext');
        window.open(`${dataDir}/users/${user}/${image_big}.${ext}`, '_blank');
    });

    function loadMessages(channelType, channelId) {
        const messagesContainer = $('#messages-container');
        messagesContainer.empty();
        let lastDay = '';
        $.getJSON(`${dataDir}/${channelType}/${channelId}/messages.json`, function (messages) {
            if (!messages) {
                return messagesContainer.append(`
                    <div style="height: 2em; padding: 15px;"><strong>No data</strong></div>`);
            }

            messages.forEach(message => {

                // day separator
                const messageDay = (new Date(message.ts * 1000)).toDateString();
                if (messageDay != lastDay) {
                    const dateSeparator = `
                    <div style="display: flex; flex-direction: column; align-items: center;">
                        <div class="message-date-separator">${messageDay}</div>
                    </div>
                    <hr class="message-date-line">
                    `;
                    messagesContainer.append(dateSeparator);
                    lastDay = messageDay;
                }

                const messageTs = message.ts.split('.').join('');
                const user = userResolver(message);

                let userName, userColor = 'AAA', userImageExt = '', userImageUrl = '', userImageTag = '';
                if (user) {
                    userName = user.profile.real_name ? user.profile.real_name : user.name;
                    userColor = user.color ? user.color : 'DDDDDD';
                    userImageExt = user.profile.image_72.substring(user.profile.image_72.lastIndexOf('.') + 1);
                    userImageUrl = `${dataDir}/users/${user.id}/image_72.${userImageExt}`;
                    userImageTag = `<img src="${userImageUrl}" class="user-icon" data-user="${user.id}" data-ext="${userImageExt}">`;
                } else if (message.user_profile) {
                    userName = message.user_profile.real_name ? message.user_profile.real_name : message.user_profile.name;
                    userImageExt = message.user_profile.image_72.substring(message.user_profile.image_72.lastIndexOf('.') + 1);
                    userImageUrl = `${dataDir}/users/${message.user}/image_72.${userImageExt}`;
                    userImageTag = `<img src="${userImageUrl}" class="user-icon" data-user="${message.user}" data-ext="${userImageExt}">`;
                } else {
                    userName = message.user ? `User ${message.user}` : 'Unknown User';
                }

                let messageText = message.text;
                messageText = miscTagHelper(messageText);
                messageText = quotTagHelper(messageText);
                messageText = linkTagHelper(messageText);
                messageText = userTagHelper(messageText);

                let messageHtml = `
                    <div class="message" id="${messageTs}">
                        <div class="message-column-icon">
                            <div class="user-icon-container" style="background-color: #${userColor};">
                                ${userImageTag}
                            </div>
                        </div>
                        <div class="message-column-body">
                            <div class="message-header">
                                <div class="user-info">
                                    <div class="user-name" data-user="${message.user}" data-ext="${userImageExt}" style="color: #${userColor};">${userName}</div>
                                    <div class="timestamp">${new Date(message.ts * 1000).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}</div>
                                </div>
                            </div>
                            <div class="message-body">${messageText}</div>
                            <div class="files-container"></div>
                        </div>
                    </div>`;

                if (message.replies) {

                    let ignoredFirstReply = 0;

                    message.replies.forEach(reply => {

                        // first reply -eq parent message.
                        if (!ignoredFirstReply++) return;

                        const replyTs = reply.ts.split('.').join('');
                        const user = userResolver(reply);

                        let userName, userColor = 'AAA', userImageExt = '', userImageUrl = '', userImageTag = '';
                        if (user) {
                            userName = user.profile.real_name ? user.profile.real_name : user.name;
                            userColor = user.color ? user.color : 'DDDDDD';
                            userImageExt = user.profile.image_72.substring(user.profile.image_72.lastIndexOf('.') + 1);
                            userImageUrl = `${dataDir}/users/${user.id}/image_72.${userImageExt}`;
                            userImageTag = `<img src="${userImageUrl}" class="user-icon" data-user="${user.id}" data-ext="${userImageExt}">`;
                        } else if (reply.user_profile) {
                            userName = reply.user_profile.real_name ? reply.user_profile.real_name : reply.user_profile.name;
                            userImageExt = reply.user_profile.image_72.substring(reply.user_profile.image_72.lastIndexOf('.') + 1);
                            userImageUrl = `${dataDir}/users/${reply.user}/image_72.${userImageExt}`;
                            userImageTag = `<img src="${userImageUrl}" class="user-icon" data-user="${reply.user}" data-ext="${userImageExt}">`;
                        } else {
                            userName = reply.user ? `User ${reply.user}` : 'Unknown User';
                        }

                        let messageText = reply.text;
                        messageText = miscTagHelper(messageText);
                        messageText = quotTagHelper(messageText);
                        messageText = linkTagHelper(messageText);
                        messageText = userTagHelper(messageText);

                        messageHtml += `
                        <div class="message reply" id="${replyTs}">
                            <div class="reply-column-icon">
                                <div class="user-icon-container" style="background-color: #${userColor};">
                                    ${userImageTag}
                                </div>
                            </div>
                            <div class="message-column-body">
                                <div class="message-header">
                                    <div class="user-info">
                                        <div class="user-name" data-user="${reply.user}" data-ext="${userImageExt}" style="color: #${userColor};">${userName}</div>
                                        <div class="timestamp">${new Date(reply.ts * 1000).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })}</div>
                                    </div>
                                </div>
                                <div class="message-body">${messageText}</div>
                                <div class="files-container"></div>
                            </div>
                        </div>`;
                    });
                }

                // add message files
                messagesContainer.append(messageHtml);
                if (message.files) {
                    message.files.forEach(file => {
                        appendFileToMessage(file, messageTs);
                    });
                }

                // add reply files
                if (message.replies) {
                    let ignoredFirstReply = 0;
                    message.replies.forEach(reply => {
                        if (!ignoredFirstReply++) return;
                        if (reply.files) {
                            const replyTs = reply.ts.split('.').join('');
                            reply.files.forEach(file => {
                                appendFileToMessage(file, replyTs);
                            });
                        }
                    });
                }
            });
        });
    }

    function appendFileToMessage(file, messageTs) {
        const fileElement = createFileElement(file);
        $(`#${messageTs} .files-container`).append(fileElement);
    }

    function createFileElement(file) {
        if (file.file_access === 'access_denied') {
            return `
                    <div class="file-bad">
                        <div style="display: block; font-weight: bold;">
                            This file isn't visible to you.
                        </div>
                        <div style="display: block; font-size: 0.85em;">
                            This file is only visible to members of the conversation where it was originally shared.
                        </div>
                    </div>`;
        } else if (file.mode === 'tombstone') {
            return `
                    <div class="file-bad">
                        <div style="display: block; font-size: 1.1em;">
                            This file was deleted.
                        </div>
                    </div>`;
        } else if (file.mimetype.startsWith('image/')) {
            return `
                    <div style="display: block; font-size: 0.9em; font-weight: bold; color: #999;">${file.name}</div>
                    <a href="data/files/${file.id}/${file.name}" target="_blank">
                        <img src="data/files/${file.id}/${file.name}" alt="${file.name}" class="file-image">
                    </a>`;
        } else {
            return `
                    <a href="data/files/${file.id}/${file.name}" target="_blank" class="file-link">
                        <img src="images/file-icon.png" alt="File" class="file-icon">
                        ${file.name}
                    </a>`;
        }
    }

});

// helpers

const userResolver = (message) => {
    if ('user' in message) {
        if (message.user in users) {
            return users[message.user];
        } else if (message.user_profile && message.user_profile.name) {
            for (const [id, user] of Object.entries(users)) {
                if (user.team_id === message.team && user.name === message.user_profile.name) {
                    users[message.user] = user;
                    return user;
                }
            }
        }
    } else if ('subtype' in message && message.subtype === 'bot_message') {
        if (message.bot_id in robots) {
            return robots[message.bot_id];
        } else {
            console.log('robot!', message); // oh, yoshimi
            for (const [id, user] of Object.entries(users)) {
                if (message.bot_id === user.profile.bot_id) {
                    robots[message.bot_id] = user;
                    return user;
                } // they don't believe me
            }
        }
    }
}

const userTagHelper = (text, url) => {
    const regEx = /<@([^>]+)>/g;
    const addTags = (id, username, color) => {
        return `<div class="user-name" data-user="${id}" data-url="${url}" style="color: #${color};">${username}</div>`;
    };
    const newText = text.replace(regEx, (match, id) => {
        const user = users[id];
        if (user) {
            username = user.name ? user.name : `User ${id}`;
            color = user.color ? user.color : 'AAA';
        } else {
            username = `User ${id}`;
            color = 'DDDDDD';
        }
        return `${addTags(id, username, color)}`;
    });
    return newText;
};

const miscTagHelper = (text) => {
    return [
        ['\n',          '<br>'],
        ['<!here>',     '<div class="message tag">@here</div>'],
        ['<!channel>',  '<div class="message tag">@channel</div>']
    ].reduce((acc, swap) => {
        return acc.replaceAll(swap[0], swap[1]);
    }, text);
};

const quotTagHelper = (text) => {
    const regEx = /```([^`]+)```/g;
    return text.replace(regEx, (match, blockText) => {
        return `<div class="message blockquote">${blockText}</div>`;
    });
};

const linkTagHelper = (text) => {
    const regEx = /<(http[^|>]+|mailto[^|>]+)(?:\|([^>]+))?>/g;
    return text.replace(regEx, (match, url, anchor) => {
        return `<a href="${url}" target="_blank">${anchor ? anchor : url}</a>`;
    });
};
