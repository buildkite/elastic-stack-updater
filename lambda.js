var AWS = require('aws-sdk');
var cloudformation = new AWS.CloudFormation();
var ec2 = new AWS.EC2();

var getPreviousTemplateKeys = function(stackName, cb) {
  cloudformation.getTemplateSummary({ StackName: stackName }, function(err, data) {
    if (err !== null) {
      cb(err, []);
    } else {
      cb(err, data.Parameters.map((obj) => obj.ParameterKey));
    }
  });
}

exports.handler = function name(event, context) {
  var stackName = event.StackName;
  var stackFile = event.StackFile;

  var params = {
    StackName: stackName,
    Capabilities: [
      'CAPABILITY_NAMED_IAM'
    ],
    Parameters: [],
    TemplateURL: 'https://s3.amazonaws.com/buildkite-aws-stack/'+stackFile,
  };

  getPreviousTemplateKeys(stackName, function(err, previousParameterKeys){
    if (err) {
      context.fail(err);
      return;
    }

    // for anything not set, use the previous value
    previousParameterKeys.forEach(function(k) {
      params.Parameters.push({ ParameterKey: k, UsePreviousValue: true });
    });

    console.log('updateStack(%s)', stackName, params);

    cloudformation.updateStack(params, function(err, data) {
      if (err) {
        context.fail(err);
        return
      }
      context.succeed(data);
    });
  });
};
