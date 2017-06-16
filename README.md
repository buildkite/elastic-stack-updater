Elastic Stack Updater
=====================

Updates our internal elastic stacks on a regular schedule

The policy is requires is:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:CreateChangeSet"
            ],
            "Resource": "arn:aws:cloudformation:us-east-1:445615400570:stack/elastic-builders/*",
            "Condition": {
                "StringEquals": {
                    "cloudformation:TemplateURL": [
                        "s3://buildkite-aws-stack/aws-stack.json"
                    ]
                }
            }
        }
    ]
}
```