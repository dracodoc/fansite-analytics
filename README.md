---
output: html_document
---
# Why I used R

Simply put, I found R is great in exploratory analysis, acceptable in performance for the given questions. I have used R in several projects with gigabytes data without any problem, and the performance are very reasonable. Using python may reduce the time used for some specific task from 20 secs to 1 sec, but I can explore all kinds of feature in R with several lines of code, which is much more productive in general.

I agree with [Hadley's opinion](https://www.reddit.com/r/dataisbeautiful/comments/3mp9r7/im_hadley_wickham_chief_scientist_at_rstudio_and/cvh7g6m/) that there are two important transition points in problem scale:

- From in-memory to disk. 
  R can only handle data in RAM by default, so R cannot scale to data bigger than RAM without using other framework like SparkR. However even if you are using python, you probably need to change the solution or framework fundamentally anyway when you have this kind of scale changes.
  
    For example we can read file by chunk and process data in streaming fashion. The feature 4 can be handled in this approach. Then R will have no problem processing the streaming data with enough speed because each chunk is significantly smaller than the whole dataset.
  
    If you do need to process the whole dataset to get the solution, then usually this kind of batch job doesn't have the strict time requirement like streaming problem.
  
- From one computer to many computers. 
  This will bring even more radical changes in solutions. There are some limit from R implementation, but R language itself is a good functional language, which have more potential to transit the algorithm to parallel or distributed computing.

# notes on solutions

**I knew my solution didn't pass the test on feature 3**. I wrote a version that meet the problem requirement and can pass the test, but I don't like the result of this problem definition. I decided to keep my original code even it will not pass the test. 

I put notes on my solutions in a RMarkdown document `Solution_notes.Rmd`. Note I only kept the relevant code in the RMarkdown so it cannot be rendered directly. You can read the already rendered html version `Solution_notes.html`. 
