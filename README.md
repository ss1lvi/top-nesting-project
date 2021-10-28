# TOP nesting project

[README.md](https://bitbucket.org/corpinfo/top-training-material/src/master/nesting-project/)

> To wrap up the program we will be allowing you to work mostly independently on a project of your choosing to show off your newly gained cloud engineering skill sets.
> ...
> Once you have come up with your idea write up a small PDF on your idea including an infrastructure design. Be prepared to get some feedback and direction. Ideally, we'll have everyone working on a unique idea.

## table of contents

- [TOP nesting project](#top-nesting-project)
  - [table of contents](#table-of-contents)
  - [markov blog](#markov-blog)
    - [points](#points)
    - [diagrams](#diagrams)
    - [references](#references)
    - [log](#log)
    - [pieces](#pieces)
    - [suggestions](#suggestions)
    - [flowchart:](#flowchart)
    - [steps](#steps)
      - [done](#done)
      - [todo](#todo)


## markov blog

a blog (or news site) staffed by a bot/bots

### points

- all posts written via markov chains
  - lambda + [markovify](https://github.com/jsvine/markovify)?
  - corpus files stored in s3?
- headless CMS
  - https://jamstack.org/headless-cms/
- static site generator
  - https://github.com/myles/awesome-static-generators
  - https://github.com/automata/awesome-jamstack#readme
  - store site in s3
- cloudfront to make it nice and hostable
- route 53 for dns
- do the infra in terraform
  - does it need a database? aurora/dynamodb?
- do the lambda in serverless
- maybe just a runway project with:
  - tf module to create domain/dns records/certs, necessary buckets, etc
  - serverless module to run gatsby
  - serverless module with python code to run markovify and publish posts

### diagrams

- static site:
  ![alt](/img/markovblog_v1.png)
- static site w/ headless CMS:
  ![alt](/img/markovblog_v2.png)
- static site w/ step function for approval
  ![alt](/img/markovblog_v3.png)

### references

- **markovify**
  - [A markov generator for aws announcement posts](https://github.com/kkuchta/aws_markov)
  - [Paging Dr. Dankenstein](https://www.eivindarvesen.com/blog/2018/06/20/paging-dr--dankenstein)
  - [A few simple corpus-driven approaches to narrative analysis and generation](https://colab.research.google.com/github/aparrish/corpus-driven-narrative-generation/blob/master/corpus-driven-narrative-generation.ipynb)
  - [Kaggle corpus search](https://www.kaggle.com/datasets?search=corpus)
  - [Meaningful Random Headlines by Markov Chain](https://www.kaggle.com/nulldata/meaningful-random-headlines-by-markov-chain)
- **strapi**
  - [How I Built My Website Using Gatsby, Strapi, and AWS](https://www.thedevdoctor.com/blog/how-i-built-my-website-using-gatsby-strapi-and-aws/)
  - [How to deploy Strapi on AWS Elastic Beanstalk using Docker](https://purple.telstra.com/blog/how-to-deploy-strapi-on-aws-elastic-beanstalk-using-docker)
  - [Strap containerized](https://github.com/strapi/strapi-docker)
- **gatsby and serverless**:
  - https://medium.com/@cbartling/deploying-gatsby-websites-using-serverless-components-d8225c1746d1
  - https://wenheqi.medium.com/deploy-multi-page-gatsby-site-to-lambda-function-1bdb91cacfe3
  - https://github.com/serverless/blog
- **cloudfront / s3**
  - https://aws.amazon.com/blogs/aws/introducing-cloudfront-functions-run-your-code-at-the-edge-with-low-latency-at-any-scale/
  - https://github.com/aws-samples/amazon-cloudfront-functions/tree/main/url-rewrite-single-page-apps
  - https://github.com/jariz/gatsby-plugin-s3/blob/master/recipes/with-cloudfront.md
    - >Next we need to ensure that your site's users aren't going to see stale content. You can do this by invalidating the CloudFront cache every time you deploy your site to S3. The easiest way to do this is to add a command to your npm deploy script within package.json.  
      > ```
      > "deploy": "gatsby-plugin-s3 deploy --yes && aws cloudfront create-invalidation --distribution-id EXAMPLEDISTRIBUTIONID --paths \"/*\""
      > ```
      > This means when you run npm run deploy the CloudFront cache will be invalidated after the deploy completes. (You'll need to change EXAMPLEDISTRIBUTIONID to your CloudFront Distribution's ID.)
- **step functions**
  - [Serverless Step Functions](https://www.serverless.com/plugins/serverless-step-functions)
  - [Implementing Serverless Manual Approval Steps in AWS Step Functions and Amazon API Gateway](https://aws.amazon.com/blogs/compute/implementing-serverless-manual-approval-steps-in-aws-step-functions-and-amazon-api-gateway/)
  - [Building your Notifications Workflow with Step Functions](https://github.com/aws-samples/aws-step-functions-notification-workflow)
  - [Build a Lambda function that's invoked by API Gateway](https://emshea.com/post/serverless-getting-started#4-build-a-lambda-function-thats-invoked-by-api-gateway)
  - [Deploying an Example Human Approval Project](https://docs.aws.amazon.com/step-functions/latest/dg/tutorial-human-approval.html)


### log

```sh
npm run build && npm run deploy

```

### pieces

- git repo
  - what goes in the repo?
  - API key for lambda to use
  - pipeline to build and deploy gatsby
- infra
  - static site bucket
    - proper configuration - static site hosting enabled, or private bucket if cloudfront function works
  - IAM role
  - route 53
  - ACM cert
  - cloudfront
    - cloudfront functions for URL rewrites?
- gatsby blog
  - pick a theme
    - customize it within reason
  - pick a domain name
- markovify script
  - python script
    - corpora
  - lambda function
  - lambda trigger
    - API gateway to manually trigger?
    - scheduled triggers?
  - serverless


### suggestions

- pipeline improvements:
  - testing
  - maybe spellchecker?
  - multiple branches - demo site and prod site
- add git creds to parameter store
- approval process
  - lambda writes posts, publishes to dev branch, but they need to be approved
  - simple workflow service?
  - some other aws service?
- lambda local execution
  - https://docs.aws.amazon.com/lambda/latest/dg/images-create.html


### flowchart:

- markovify
  - write headline
  - write post
  - output txt file to bucket
- submitter
  - clone git repo
  - get txt file from bucket
  - place in proper folder / format
  - commit to git
- pause
- notify for approval

### steps

#### done

- lambda: writer
- lambda: publisher
- state machine w/ email approval
- s3 bucket for lambda usage
- github repo w/ main/test branches
- github actions build script
- s3 bucket for gatsby w/ static site
- cloudwatch events schedule trigger for state machine

#### todo

- lambda: cleanup
  - remove post from s3 bucket
- build IaC
  - terraform + sls
    - step function in sls or tf?
    - buckets in sls or tf?
    - let sls handle its own iam role
    - copy needed files into buckets w/ tf?
    - upload private key for github w/ tf?
  - runway - yeah why not
- remake github repo for website
  - needs a main and a dev branch
  - need env variable so the main and dev branches build to their own s3 buckets
  - need to add cloudfront invalidate to the deploy process
  - need to test PR build process
- markovify improvements
  - find another corpus to use
  - try out spaCy
- blog improvements
  - maybe get a new theme
- README
  - delete a lot of this
  - explain what it does
  - explain how it does it
  - explain how to do it yourself