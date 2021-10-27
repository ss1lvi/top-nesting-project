console.log('Loading function');
const AWS = require('aws-sdk');
exports.lambda_handler = (event, context, callback) => {
    console.log('event= ' + JSON.stringify(event));
    console.log('context= ' + JSON.stringify(context));

    const executionContext = event.ExecutionContext;
    console.log('executionContext= ' + executionContext);

    const executionName = executionContext.Execution.Name;
    console.log('executionName= ' + executionName);
    
    const executionComment = executionContext.Execution.Input.Comment;
    console.log('executionComment= ' + executionComment);

    const statemachineName = executionContext.StateMachine.Name;
    console.log('statemachineName= ' + statemachineName);

    const taskToken = executionContext.Task.Token;
    console.log('taskToken= ' + taskToken);

    const apigwEndpint = event.APIGatewayEndpoint;
    console.log('apigwEndpint = ' + apigwEndpint)

    const emailSnsTopic = "arn:aws:sns:us-east-2:329082876876:human-approval-test-SNSHumanApprovalEmailTopic-T08K4IIFLD6K";
    console.log('emailSnsTopic= ' + emailSnsTopic);
    
    const articleInput = event.BlogPost;
    console.log('articleInput= ' + articleInput);
    
    const articleTitle = articleInput.body.title;
    console.log('articleTitle= ' + articleTitle);
    
    const articleBody = articleInput.body.body;
    console.log('articleBody= ' + articleBody);
    
    const articleSlug = articleInput.body.slug;
    console.log('articleSlug= ' + articleSlug);
    
    const approveEndpoint = apigwEndpint + "/execution?action=approve&ex=" + executionName + "&sm=" + statemachineName + "&slug=" + articleSlug + "&taskToken=" + encodeURIComponent(taskToken);
    console.log('approveEndpoint= ' + approveEndpoint);

    const rejectEndpoint = apigwEndpint + "/execution?action=reject&ex=" + executionName + "&sm=" + statemachineName + "&slug=" + articleSlug + "&taskToken=" + encodeURIComponent(taskToken);
    console.log('rejectEndpoint= ' + rejectEndpoint);

    var emailMessage = 'A new article is born! \n\n';
    emailMessage += 'This is an email requiring an approval for a newly written article. \n\n'
    emailMessage += 'Please check the following information and click "Approve" link if you want to approve. \n\n'
    emailMessage += 'Execution Name -> ' + executionName + '\n\n'
    emailMessage += 'Execution Comment -> ' + executionComment + '\n\n'
    emailMessage += 'Article Title -> ' + articleTitle + '\n\n'
    emailMessage += 'Article Slug -> ' + articleSlug + '\n\n'
    emailMessage += 'Article Body -> ' + articleBody + '\n\n'
    emailMessage += 'Approve ' + approveEndpoint + '\n\n'
    emailMessage += 'Reject ' + rejectEndpoint + '\n\n'
    emailMessage += 'Thanks!'
    
    const sns = new AWS.SNS();
    var params = {
      Message: emailMessage,
      Subject: "Required approval for new blog article",
      TopicArn: emailSnsTopic
    };

    sns.publish(params)
      .promise()
      .then(function(data) {
        console.log("MessageID is " + data.MessageId);
        callback(null);
      }).catch(
        function(err) {
        console.error(err, err.stack);
        callback(err);
      });
}
