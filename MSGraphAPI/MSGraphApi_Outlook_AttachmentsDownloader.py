import requests
import os
import time

'''

This Python script uses the Microsoft Graph API to download email attachments from Microsoft Outlook (web/owa/online). 
It searches for emails with a specific subject and within a specific date range, then downloads the attachments of these emails to a specified location. 
The script handles rate limits by waiting and retrying the request after a specified amount of time.

'''


# get the access token from https://developer.microsoft.com/en-us/graph/graph-explorer
msGraph_access_token = ''
file_path_destination = 'C:\\temp\\attachments\\'
subject = 'invoice'
start_date = '2022-01-01T00:00:00Z'  # utc timezone
end_date = '2022-12-31T23:59:59Z'  # utc timezone


GRAPH_API_ENDPOINT = 'https://graph.microsoft.com/v1.0'


def download_email_attachments(message_id, headers, save_folder):
    try:
        with requests.Session() as session:
            session.headers.update(headers)
            response = session.get(
                GRAPH_API_ENDPOINT +
                '/me/messages/{0}/attachments'.format(message_id)
            )

            attachment_items = response.json()['value']
            for attachment in attachment_items:
                file_name = attachment['name']
                attachment_id = attachment['id']
                attachment_content = session.get(
                    GRAPH_API_ENDPOINT +
                    '/me/messages/{0}/attachments/{1}/$value'.format(
                        message_id, attachment_id)
                )
                print('Saving file {0}...'.format(file_name))
                with open(os.path.join(save_folder, file_name), 'wb') as _f:
                    _f.write(attachment_content.content)
        return True
    except Exception as e:
        print(e)
        raise


def main():
    url = GRAPH_API_ENDPOINT + '/me/messages'
    headers = {
        'Authorization': 'Bearer ' + msGraph_access_token,
        'Content-Type': 'application/json'
    }
    params = {
        '$filter': "hasAttachments eq true and contains(subject, '" + subject + "') and receivedDateTime ge " + start_date + " and receivedDateTime le " + end_date,
        '$expand': 'attachments'
    }

    backoff_time = 1  # initial backoff time in seconds
    while url:
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            messages = data['value']
            for message in messages:
                print(f"Subject: {message['subject']}")
                download_email_attachments(
                    message['id'], headers, file_path_destination, msGraph_access_token)
            url = data.get('@odata.nextLink')
            params = None  # Only use params for the first request
            backoff_time = 1  # reset backoff time
        elif response.status_code == 429:
            wait_time = int(response.headers.get('Retry-After', backoff_time))
            print(f"Rate limit exceeded. Waiting for {wait_time} seconds.")
            time.sleep(wait_time)
            backoff_time *= 2  # double the backoff time for the next potential 429
        else:
            print(f"Request failed with status code {response.status_code}")
            print(response.json())
            break


if __name__ == "__main__":
    main()
