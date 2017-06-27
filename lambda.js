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

var getSubnetFromTemplate = function(stackName, logicalResource, cb) {
  var params = {
    LogicalResourceId: logicalResource,
    StackName: stackName,
  };
  cloudformation.describeStackResource(params, function(err, data) {
    if (err) cb(err, []);
    else     cb(err, data.StackResourceDetail.PhysicalResourceId);
  });
}

var getAvailabilityZoneFromSubnet = function(subnetId, cb) {
  ec2.describeSubnets({ SubnetIds: [ subnetId ] }, function(err, data) {
    if (err) cb(err, null);
    else    cb(err, data.Subnets[0].AvailabilityZone);
  });
}

var getAvailabilityZonesFromStack = function(stackName, cb) {
  getSubnetFromTemplate(stackName, 'Subnet0', function(err, subnet0) {
    if (err) {
      return cb(err, null);
    }
    getSubnetFromTemplate(stackName, 'Subnet1', function(err, subnet1) {
      if (err) {
        return cb(err, null);
      }
      getAvailabilityZoneFromSubnet(subnet0, function(err, az1) {
        if (err) {
          return cb(err, null);
        }
        getAvailabilityZoneFromSubnet(subnet1, function(err, az2) {
          if (err) {
            return cb(err, null);
          }
          return cb(err, [az1, az2]);
        });
      });
    });
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

    getAvailabilityZonesFromStack(stackName, function(err, availabilityZones) {
      if (err) {
        context.fail(err);
        return;
      }

      // we have to set an availability zone because it bloody well changes and breaks things.
      params.Parameters.push({
        ParameterKey: 'AvailabilityZones',
        ParameterValue: availabilityZones.join(','),
        UsePreviousValue: false,
      })

      // for anything not set, use the previous value
      previousParameterKeys.forEach(function(k) {
        if (k != "AvailabilityZones") {
          params.Parameters.push({ ParameterKey: k, UsePreviousValue: true });
        }
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
  });
};