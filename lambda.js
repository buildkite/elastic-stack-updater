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

var getNewTemplateKeys = function(templateURL, cb) {
  cloudformation.getTemplateSummary({ TemplateURL: templateURL }, function(err, data) {
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
  var templateURL = 'https://s3.amazonaws.com/buildkite-aws-stack/'+stackFile;

  getNewTemplateKeys(templateURL, function(err, newParameterKeys){
    if (err) {
      context.fail(err);
      return;
    }

    getPreviousTemplateKeys(stackName, function(err, previousParameterKeys){
      if (err) {
        context.fail(err);
        return;
      }

      var params = {
        StackName: stackName,
        Capabilities: [
          'CAPABILITY_NAMED_IAM'
        ],
        Parameters: [],
        TemplateURL: templateURL,
      };

      // for anything not set, use the previous value
      previousParameterKeys.forEach(function(k) {
        if (newParameterKeys.indexOf(k) !== -1) {
          params.Parameters.push({ ParameterKey: k, UsePreviousValue: true });
        }
      });

      console.log('updateStack(%s)', stackName, params);

      cloudformation.updateStack(params, function(err, data) {
        if (err) {
          context.fail(err);
          return;
        }
        context.succeed(data);
      });
    });
  });
};
