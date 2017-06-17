Elastic Stack Updater
=====================

Updates our internal elastic stacks on a regular schedule. Since updating the stack requires admin IAM permissions, a lambda function is used. 

To trigger the lambda function the following policy is required:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "InvokePermission",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": "arn:aws:lambda:us-east-1:445615400570:function:updateElasticStack"
        }
    ]
}
```

