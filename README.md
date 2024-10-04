SLACKUP - a tool to back up and view backed-up Slack data.

USAGE
       slackup [-h] [-n] [-r]

DESCRIPTION
       Back up and view your Slack messages. Useful for planned account and user termination.

OPTIONS
       -h, --help
              Show this help file

       -n, --no_download
              Do not download file attachments from Slack

       -r, --re_download
              Download file attachments even if files already exist

SETUP
       https://papermtn.co.uk/retrieving-and-using-slack-cookies-for-authentication/

       Retrieving and Using Slack Cookies for Authentication

       May 6, 2023

       Slack, like many other services, uses cookies to store authentication and session information.

       What is interesting with Slack, however, is that one particular cookie can be used to generate a user 

       session token, and provide you programatic access as the user who generated it.

       This cookie is imaginatively named d, and is available from a browser with an authenticated Slack session.

       Getting the d (cookie)
       ----------------------
       In a browser window, authenticated to Slack and with Slack open, go to developer tools and head to the 

       storage section (in Chrome this is under Application -> Storage)

       Under cookies expand app.slack.com, and you will see all the cookies that Slack stores in the browser for the session.

       The one you want to copy is the d cookie, that should start with xoxd-...

       Take notice of the expiry date on this cookie, 10 years time. It is very long lived.

       Turning this into a User Session Token

       This cookie can used in a HTTP request to a Slack workspace the user has access to to retrieve a user session token, 

       which will begin xoxc-..., this token can then be used in place of a user or bot token for the Slack API.

       Make a cURL request to a workspace you know the user has access to. I know that the user cookie I’ve got has access to 

       the slack domain westeros-inc, so I send a cURL request like this:

              curl -L --cookie "d=xoxd-e0f1f2a3c4e5d6..." https://westeros-inc.slack.com

       In the response, amongst other things, Slack returns the user session token in JSON data under the api_token key.

       We can pipe this output to grep against a regex pattern to get the user session value:

              curl -L --cookie "d=xoxd-e0f1f2a3c4e5d6..." https://westeros-inc.slack.com | grep -ioE "(xox[a-zA-Z]-[a-zA-Z0-9-]+)"

       Using this token
       ----------------
       This token can be used in place of a user (xoxp-) or bot (xoxb-) token for API authentication to Slack:

       Summary
       -------
       1. Copy token value from logged-in browser at app.slack.com.

       2. Copy complete cookie from logged-in browser at app.slack.com (find d-cookie).

       3. Extract d-cookie from complete cookie and add to config file.:wq