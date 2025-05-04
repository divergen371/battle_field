/**
 * SNSからの通知をSlack Webhookに転送するLambda関数
 */

const https = require("node:https");
const url = require("node:url");

exports.handler = async (event) => {
  try {
    console.log("SNSイベントを受信:", JSON.stringify(event, null, 2));

    // SNSメッセージを解析
    const snsMessage = event.Records[0].Sns;
    const messageText = snsMessage.Message;
    const subject = snsMessage.Subject || "AWS予算アラート";

    // Webhook URLを環境変数から取得
    const webhookUrl = process.env.SLACK_WEBHOOK_URL;
    if (!webhookUrl) {
      throw new Error("SLACK_WEBHOOK_URL環境変数が設定されていません");
    }

    // Slackメッセージを構築
    const slackMessage = {
      blocks: [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: `⚠️ ${subject}`,
          },
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: messageText,
          },
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: `*通知日時:* ${new Date(
                snsMessage.Timestamp
              ).toLocaleString()}`,
            },
          ],
        },
        {
          type: "divider",
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "詳細はAWS Billingコンソールで確認してください。",
          },
          accessory: {
            type: "button",
            text: {
              type: "plain_text",
              text: "Billingを開く",
            },
            url: "https://console.aws.amazon.com/billing/home",
            action_id: "button-action",
          },
        },
      ],
    };

    // Slackに通知を送信
    const response = await sendToSlack(webhookUrl, slackMessage);
    console.log("Slack通知結果:", response);

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        message: "Slack通知を送信しました",
      }),
    };
  } catch (error) {
    console.error("エラーが発生しました:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ success: false, message: error.message }),
    };
  }
};

/**
 * Slack Webhookに通知を送信する
 */
async function sendToSlack(webhookUrl, message) {
  return new Promise((resolve, reject) => {
    const parsedUrl = url.parse(webhookUrl);
    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.path,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
    };

    const req = https.request(options, (res) => {
      let responseBody = "";
      res.on("data", (chunk) => {
        responseBody += chunk;
      });

      res.on("end", () => {
        if (res.statusCode === 200) {
          resolve(responseBody);
        } else {
          reject(
            new Error(
              `Slackからエラーレスポンスを受信: ${res.statusCode} ${responseBody}`
            )
          );
        }
      });
    });

    req.on("error", (error) => {
      reject(error);
    });

    req.write(JSON.stringify(message));
    req.end();
  });
}
