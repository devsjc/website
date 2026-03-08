---
title: "Why I secretly rewrote my company's core infrastructure in my spare time"
subtitle: "an introspection on poor work decisions"
description: ""
author: devsjc
date: 2026-03-02
tags: [architecture, culture, quality]
---

_This is different post to my usual style, in that it is purely an opinion piece: no citations, just my own thoughts. It is not intended to be read as any sort of objective, universal truth - so take any information on board with that proviso in mind!_

Have you ever been in the following situation: you're a software engineer, working for a company that you've been at for a couple of years. You know the domain; you know the tech stack; you've developed good working relationships with your colleagues - and through these avenues, you've become aware that some parts of the codebase are a liability, but are too far gone for minor improvements to help: they need a complete overhaul. You're confident you've got the experience required to do a better job, but it isn't in your remit, and besides: you're already trying to squeeze more work into your working hours than there is necessarily time for. Management don't seem to realise anything is amiss. What do you do?

This is exactly where I found myself a year ago - and what I decided to do, was to **secretly rewrite the entire thing, in my own time**. I will discuss how, of course, but potentially more interesting is to explore _why_: why rewrite something that was, ostensibly, working? Why do it in secret? Why _care_? It's a set of questions that will encroach upon many facets of both the _practice_ of software development, and the act of _pursuing_ said practice in a corporate environment (specifically, in a startup).

I also ought to state up top that I wouldn't do it again, nor would I recommend anyone else does: it isn't a good way of going about work, for a number of reasons. But this further compels me to investigate the _why_. 

The answers to those "why"s, I think, fit into three main categories:

- Performance
- Code Quality
- Culture

Let's take a look at each one in turn. I'll begin by getting the technical stuff out of the way, and then move on to the broader, more ill-defined aspects of the process. As such, I'll be addressing the less interesting _why I did it_ question, _before_ the (admittedly clickbait-y) headline question _why I did it **in secret**_. So if that is the more interesting bit to you, feel free to skip the first two sections.

For the other readers, lets turn back the clock a year-odd, and get into it!


## Motivation 1: Performance

### The existing backend: the "classic startup stack"

I should give a bit of background on what the preexisting stack was.

As is the case with a lot of software products, the core of the service was effectively a database with an application-specific model, and a suite of tooling on top of that to handle internal access and business logic. The database model was written in Python using SQLAlchemy, and the access tooling came in the form of a bunch of read and write functions that incorporated the above, written into a pip-installable library released on PyPi. This library was then imported into the various microservices that populated the database, as well as into an API that exposed the data to users, and finally to a frontend.

All fairly standard stuff, and a classic choice for a startup wanting to get from zero to production in as little time as possible. 

### ...but worse

Although it wasn't quite as simple as I've just described. As a startup grows, understanding of the domain deepens, and priorities change. The stack is then modified and shifted to support these changes. If it isn't built from the start with a layered approach using proper separation of concerns, adding these in can result in a convoluted mishmash of code: which is exactly what had happened here.

Instead of one database, there were two; almost identical, but ever-so-slightly different. Both had their own separate but very similar libraries; and each library had a multitude of functions performing the same or very similar jobs. Their usage was unclear, as was their behaviour. Modifying the database - or the access functions - required updating the libraries in every deployed service at the same time as any migrations were deployed. The tables themselves were written without knowledge of the most common tasks they'd be likely to perform, resulting in slow queries, and therefore, slow access library functions and API routes. Plasters had been, well, plastered over the cracks: reliance grew on complicated cacheing; beefing up deployment instances; more and more tables and indexes, and so on. 

This resulted in a very messy core stack, far from the trumpeted simplicity the classic stack can bring - the codebases were complex and convoluted, and the patches hadn't solved the performance issues: the most common queries were taking upwards of a _second_, sometimes a second and a half (and this from a Postgres table with only around six million rows-!). Four people accessing the UI concurrently would make the API fall over (due to huge upfront fetches being used as a workaround for the slowness of on-demand querying). Some services - and some data analysts - avoided the libraries altogether, in an attempt to speed up and simplify their own tasks. The architecture diagram was something like this:

```
             SQLAlchemy                              
                 ┌─┐            ┌──────┐             
      ┌──────────┼─┼────────────┘      │             
 ┌────▼────────┐ │ ┼────────────►      │             
 │             ┼─► ┼────┐       │      │             
 │ Database 1  │ │ │    │       └──────┘             
 │             ┼─┼─┼──┐ │       ┌──────┐    ┌──────┐ 
 └──┬──────────┘ └┬┘  │ └───────►      │    │      │ 
    │             │   └─────────► API  ┼────►  UI  │ 
 ┌──┼──────────┐ ┌▼┐    ┌───────►      │    │      │ 
 │  │          │ │ │    │       └──────┘    └──────┘ 
 │ Database 2  ┼─► ┼────┘       ┌──────┐             
 │  │          ┼─┬─┼────────────►      │             
 └──┼┬─────────┘ │ ┼────────────►      │             
    ││           │ │            │      │             
    ││           └─┘            └──────┘             
    ││       SQLAlchemy       Microservices          
    ││                                               
    └┴───► Analysis                                  
```

Database access was everywhere; session/transaction management was ad hoc; traceability was minimal. Memory leaks in the design of the libraries periodically broke deployments. It was very difficult to know where to look to find anything, and when you did find it, it was difficult to know exactly what it did. It screamed out for simplification, and consolidation.

Now, I'll describe where the major contributions to the poor performance came from; but first, I want to take a second to explore how ending up in this position is not uncommon - nor is it necessarily anyone's fault.

### This is somewhat to be expected

So, the existing solution was slow.

However, it _did_ all technically _work_ - at least to the scale the company operated at the time. Sure, it crashed with four users - but the company only had one. And sure, it took over a second to serve data, but there was no precedent or reason for doing otherwise. And to be clear, I'm not lambasting the original writers here: when getting a startup off the ground, and trying to survive the early years, _speed_, _market fit_, and _proving the concept_ are far more important than scalability, optimization, or adherence to architectural design patterns. Code is being built for **now**; the company might not _exist_ in _one year_: never mind trying to write code that'll be maintainable in five. On top of this, the first attempt at writing code will never be the best solution: as during that process the scope expands, and new problems and solutions are discovered along the way - a full rewrite will almost always yield better results; as it can be carried out with a more holistic and well defined view of the overall problem space. There are so many _unknown unknowns_ that the sliding and shifting of the product - and as such, the change in the job of the backend - is unavoidable; and being in front of, and malleable, to these shifts are what keeps the startup alive. A **Domain Expert** is far more valuable than a Data Engineer.

But a Data Engineer I am. Handling the backend or the infrastructure, however, wasn't in my job description; but previous experience architecting and maintaining backends in industry meant I was aware that _things could be better_. And oftentimes, at least for me, it's the _knowing_ that things can be improved that is the major cause of frustration when dealing with them as they are.

I said above that the existing backend was an example of a "classic startup stack": which I define (glibly) as: Python across the board; Postgres managed by SQLAlchemy and alembic; FastAPI up top. There are very good reasons this is ubiquitous across early startups - it's very quick and easy to set up, and requires little extra knowledge on top of the preexisting Python that everyone even adjacent to tech already knows. And it works all well and good to begin with - in fact, it can work just fine at scale, if done well. But there's also very good reasons why, in industry, production services are written in statically-typed languages, and ORMs are used more sparingly. At a certain point, it can be helpful for a startup to **mature**: to take some learnings from industry, where large user bases and SLA guarantees make scalability and reliability of paramount importance.

Lets take a look at where the improvements could be made.

### Raw SQL is "ORMless"

I'll start with the ORM. I agree that they are very helpful in certain scenarios: for instance, they can make building a database-backed app much easier for developers that don't have database or SQL experience; furthermore, they are useful in the instance where swapping out database types regularly is a requirement (say testing with SQLite, and deploying with Postgres). However, the very abstractions that make these behaviours possible can, at a certain level of usage, serve to work _against_ the ORM - especially when it comes to single-database usage. 

At this point, the abstractions begin to be a burden, not a boon. Firstly, they can prevent the leveraging of some of the more powerful, highly specific functionality of the database in question, due to lack of support (at least without writing raw SQL strings - but that somewhat defeats the point of the ORM). As an example, `COPY FROM` - the fastest bulk insert method in Postgres - isn't natively supported in SQLAlchemy (at time of writing). Using the query language of the chosen database directly will most always allow for faster queries, due to this ability to exactingly employ the power of the database engine itself. Secondly, the abstractions can reduce the cognitive load to such a degree that the writer is prevented from thinking about things that, in actuality, should be carefully considered; such as transaction and session management, query/index alignment, and even migrations. Relying on the "automagic" nature of an ORM to handle these concepts seems easier at first, but being thoughtful about them from the get go will save headaches later. And thirdly, the abstractions can make it much more difficult to debug and analyze database performance. A raw SQL query can be examined easily with query analyzers: both in-database, and via external visual tools; and in this manner performance can be easily monitored, queries tweaked, and indexes improved. With an ORM, the SQL being run is hidden from the developer, and it can be hard to understand from the ORM code exactly what the produced SQL will even be - it has to be extracted before it can be investigated. Finally, raw SQL is highly readable, and very searchable for online help! Far from something that should be avoided due to any perceived complication: it is simple, explainable, and universal (database-specific flavours aside). In fact, I found during my rewrite that the PostgreSQL query for one specific use case was around fifty lines of code, whilst the SQLAlchemy code for the same functionality was six times that.

In my opinion, the argument that most strongly **supports** the usage of ORMs is that they provide _type-safe wrapping_ of database data into application code (and I'm going to come on to type safety more thoroughly in a minute). But an ORM isn't necessary to achieve this - at least, not an ORM in the classic sense. Tools like [sqlc](https://github.com/sqlc-dev/sqlc) and [sqlx](https://github.com/launchbadge/sqlx) enable generation of boilerplate application code from native SQL definitions of migrations and queries.

All this being said, I ought to take a second here to point out that: although I claim above that raw SQL enables greater performance, it is not a solution in and of itself. Queries are only as fast as the table design - and, within that, the index choices under query - _enables_ them to be. Ideally, a database _schema_ should be designed _cognisant of the most common, business-critical query patterns_; and conversely, the _queries_ should be written _mindful of the database schema_. (Consider the example where letters in an intray have been carefully ordered alpabetically by adressee. This is useless if the usual desire is to access "all the letters from yesterday"). Again, however, this symbiosis is very hard to achieve in the early startup environment: developers don't have the benefit of several years' worth of service provision to have that clear picture of exactly _how_ that service is most commonly going to be used. I, however - having arrived after this point, and having had over a year to both work with the existing product and get to grips with the domain - was in the privileged position of being able to determine what the service's most common access patterns were, and where the bottlenecks lay. This meant I was situated to do exactly the above: think up a new database schema, that encapsulated all the existing functionality of the existing pair (and enabled some new stuff), but was hyper-optimized for the performance of the critical access patterns; and write associated queries that made the most of this new design.

### Python should Go

Aside from the ORM, there was at hit to performance arising from the usage of Python. Now as I've said earlier, Python isn't in itself the whole issue: it can be written very well, and the [new tooling coming out around it](https://astral.sh/) is really helping to normalize quality Python - plus, it's impressively fast for certain applications. I'm also aware that in the world of Machine Learning, there is little viable option other that to use Python - so to a degree, there's no escaping some production Python when ML is part of the product.

But when Python isn't written with production in mind, it can serve to be a liability if thrust into that role. By "not written with production in mind", I'm really meaning either _written without the perspective of someone trying to debug a production service_ or, _written without much experience of backend engineering_. So: no type hinting; no type checking; no thought to logging or traceability; or to failure modes; or configuration; or to the architectural design of the service: to modularity, or hexagonality; and so on. And to a degree, this _is_ the fault of Python: because it's so easy to produce, it's possible to write and deploy services without having to think about any of that. And don't get me wrong: that's great! It makes coding and deploying software accessible to a wider audience; to developers with experience in all different sectors. Far be it from me to gatekeep: as someone who enjoys writing and deploying code, I believe everyone should get the opportunity to experience that same satisfaction.

However, when that _isn't_ great, is when crucial services, central to a company's core product, exhibit this lack of rigour. Then you're getting all the worst of Python - the comparative slowness; the surprise exceptions. For me, core services such as these should, wherever possible, be written in a statically typed, compiled language. They will almost always be faster than Python (or at least will have a higher speed ceiling); they'll eliminate a whole suite of bugs at compile time; they'll be more stable. Not to mention, due to their more common usage as production languages, they might be easier to hire more specialized roles for (at least in my experience!). 

Truthfully, the majority shareholder in the slowness of the existing stack as described above, was the database schema and query design, **not** Python. Most of the gains in speed were to be found there. But the Python as written was undoubtedly a contributing board member (and speed wasn't the only major motivation for rewriting the whole thing - I'll come on to that)! So, with the ease of understanding of a mostly Python development team in mind, and the knowledge of the ORMless capabilities of `sqlc`: **Go** seemed the obvious best choice for any rewrite. Interaction with existing Python services could be handled easily enough via a language-agnostic gRPC API.

### Ambitions to scale

So, these were the main areas where performance and reliability gains could be made. But, as mentioned a couple of sections back, the existing stack _did_ perform to requirements. So why was the performance a motivation for me at all? 

Well, partly - and from that same section - because I knew it could be better. This stems from the purely obsessive, pedantic developer in me, that wants to write and work with nice, optimal code; code that one can be proud of. But, more pressingly, the company had expressed ambitions to scale - and I knew the stack as it stood wasn't up to the task. More plasters wouldn't cut the mustard: it needed a full redo.

But there was another major factor that fed my desire to perform the rewrite - a _social_ one, as opposed to a _technical_ one, though it may not seem it at first: **code quality**.


## Motivation 2: Code Quality

### Quality for maintainability

It feels more relevant than ever before to consider the importance of code quality.

Pre LLMs, it was easy enough to dismiss developers advocating for code quality as needlessly chasing beauty, in opposition to writing something that works and is actually released on time. I believe it was Anselm's Ontological Argument that stated _code that is perfect but isn't deployed is less perfect than any code that is deployed_ (or something along those lines...). But now AI slop is all over the shop, it has created a more prominent and vocal discussion around the importance of quality from a maintenance standpoint. It's become incredibly easy to produce mediocre, overly verbose, poorly considered reams of LLM soup. But this code, by the very nature of having _not_ been written (and by likelihood of not having been thoroughly read, though some people do, I'm aware), will not be part of the fully comprehended, internal understanding of a codebase that a developer gains through the process of writing it. As a result, the logical pathways of the code become less and less clear, and maintaining the codebase becomes more and more challenging. In this way, poor code quality reduces maintainability.

But this isn't the angle I want to approach this with, as it's been spoken about a lot already. Rather, there's a slightly subtler consequence of neglecting quality that I think is more interesting - especially in the startup reference frame. Why is a reduction in maintainability _actually_ an issue? Well, it reduces downtime. How? A more understandable codebase makes it easier for a developer visiting the codebase only intermittently to debug problems, or add fixes and features: i.e.: _It makes developers' lives easier_. This, to me, is the real crux of the matter.

### Keeping developers happy

I'm not - and have never been - in charge of a company, for a number of good reasons - chief among which being that I would almost certainly hate everything about it, and be terrible at it as a consequence. But if I were in charge, and if I had working for me a development team that were all highly talented, driven, motivated, and so on; who's work held the company up and pushed it forward - then I would imagine priority number _two_ (right behind actually delivering my product to a standard that keeps their salaries paid), would be _to keep them happy_. Their knowledge of the internal workings, combined with their quality of output, means that to have to replace them would come at both great cost to, and the great detriment of, the company.

Now, clearly a competitive salary, generous leave, good benefits, and plenty of socials would be the main ways to achieve this, so lets assume I'm providing all that in my hypothetical leadership role. There's another factor contributing to developer happiness that I want to focus on here: since developers spend most of their working hours _developing_ (i.e. writing, reviewing, deploying, testing code, and so on), a not insignificant part of _keeping them happy_ comes from making sure that this development process is as frictionless as it can be. And here is where **code quality** plays its part.

Imagine being an analyst, and every two weeks or so you have to produce a report from company data. You go to remind yourself how exactly to fetch that data; you end up at the data access library. But then you remember that there are actually _two_ slightly different libraries, and you're not sure which to use. So you delve into the codebases of each library, but it's unclear where the functions you need are. Perhaps this one does what you want it to do - but it isn't clear from the documentation. You run it to be sure, and it takes a minute and a half to complete, when you'd expect it to be a quick return; and it isn't quite right when it does. You need to make a change to the code to suit your needs, but you're not sure if any external systems are depending on that function as it stands - not that there are any tests enforcing it's behaviour anyway - and you don't want to wait for a PR review anyway: this report needs doing. So you sack it in and connect directly to the database, remind yourself of the table structure, and pull what you need. During this whole process, you're not enjoying your work: you're _irritated_: irritated it's taking as long as it is; irritated you're having to look through this stuff again when you know you did it last time and it still doesn't make any sense; irritated because you know it shouldn't be like this. And each time this irritation is there, you lose a bit of motivation; lose a bit of drive. Edge closer to needing a break, to burnout. Because you yourself care about writing quality code, it irks you all the more when you're forced to interface with some that isn't.

This is exactly the danger that poor code quality poses - and exactly the kind of situation that my colleagues were finding themselves in, that year-and-a-bit ago. It isn't just poor code quality that can feed this cycle either - I'm using it somewhat as a proxy to describe a general lack of application of consideration or _care_ to the many facets of the development cycle, across all the tooling: factors that by themselves seem overly pedantic to focus on, but together slowly build frustration, and drive away talent. Its the "boring" stuff, like consistent name schemes; standardised linting rules; quick test suites and CI pipelines; simple deployment processes; easy monitoring; local running; well-written code, etc. And _care_ is exactly the word - the best developers are as good as they are because they _care_ about the quality of their output: there is inherent satisfaction in doing a job properly. When consistently forced to interface with code and processes built without care, that "best" development capability is curtailed. 

### Back to the stack

As a Data Engineer, my job - insofar as I understand it - is not just creating and managing stores of data, but also writing tooling around that data for ease of access. A product is only any good if it is actually useable; and in a data-driven world where data is the product, the tooling serving up this data carries equal weight to the storage of it. If a colleague is getting irritated when they're trying to access data through my tooling - well, I've not done a good enough job of listening to what is required and providing it. 

In the case of the existing stack's two Python database access libraries, they were exactly this kind of irritating tooling. No one wanted to touch them or change them, or review PRs on them, or roll out updates to them. Even if the underlying database had been the most brilliantly designed masterpiece of data engineering, it wouldn't have mattered: the access functions made it slow and incomprehensible. This is what I mean when I say they carry equal weight; it's a direct analogue to the earlier proposition that the database schema and the queries ought be designed mindful of each other - doing one component perfectly is pointless if the other is a hot mess.

Now - and stay with me here - I _like_ all my colleagues, and I selfishly didn't want any of them to leave! So another big motivation for performing a rewrite was _to have the chance to make their lives that bit easier_. I could survey the most regular users of the current core, find out their biggest pain points; their access patterns; their nice-to-have's - and feed all that into the redesign. But, as above - regardless of the performance gains I might be able to make, if it came out just as difficult to work with as the previous implementation, then so far as I was concerned I might as well not have bothered at all.

So, from a technical standpoint, the goal and the pathway to it, were clear. Make it quicker, make it sturdier, make it easier to use: a backend fit for purpose. But all of this would be moot if it remained as just a possibility - it needed to actually be deployed and implemented to reap the benefits. And that meant tearing out and replacing the entire core of the live service - no mean feat! Not to mention, none of this whatsoever was in my job description!

I had to pitch this in the right way.


## "Motivation" 3: Culture

### Finding a strong enough argument

Now we come onto the _why in secret_ part of the question.

Presumably, you, the reader, work in some kind of organisational structure - or at least tangentially in a group setting. And maybe at some point in your role, you've had to suggest changes to some process or element of your job, and get approval to enact them. This approval is likely based on the merits of the suggestion, weighted against the associated costs; be they financial, temporal or social. An almost mathematical equation - but balancing this equation is obviously not a quantitative process: differing perspectives lead to different weightings of each piece of the formula. Usually, it's up to you to _persuade_ the decision-makers to see it your way, as it were - as they will by default err on the side of business-as-usual.

If you take a minute to think about the last time you had to do this, hopefully you're remembering a conversation whereby you explained what your new idea was, the value in it was seen quite quickly - perhaps they were at least somewhat aware already of the bottleneck under address - and the green light was given. It might not even register as a pitch, because it was such a straightforward and usual process. But now consider how it might have gone had that pitch entailed _completely scratching and redoing something extremely central to your deliverable_ - a much harder sell. How might you change your approach? And, on top of that, what do you do when you know there is _no such existing awareness_?

To me it seemed the sensible thing to do was to try to pre-empt any question or qualms that might arise when I attempted the requisite persuasion to balance the equation in my favour. And through this process, I convinced myself that there was no obvious line of argument I could take that would result in getting the go-ahead for the full reimplementation. Were I to raise the point that "the database and queries are slow, and written antithetical to the common usage patterns", I imagined the response would be "modify the SQLAlchemy definitions, make the relevant migrations and updates to the access functions, and redeploy". Fair enough: it's the smallest surface of change; it's readable; it's low risk. "Sure", I would say, "but this won't make the database any easier to use for developers, because of the haphazard tooling; it's hampering integration" - which again, would yield the reasonable response of "Well, update the tooling as well". But _that_ wouldn't fix the complexity and interdependency of the deployment, which in itself was a major barrier to scaling, and a deterrent to onboarding. "Not to mention, it would probably take me _longer_ to refactor all of that than it would to simply rewrite it.", I would conclude. The response to that, of course, is "Then it isn't worth the time. It works, and we can improve as we go." Which puts me back where I began: only able to drive change via the minor improvements; adding more plasters.

This is where I found myself stuck. When I played out the pitch, it seemed there would be too much _resistance to change_ - change to a whole new language; to a new API framework; a new deployment architecture. There are paying users of services backed by the existing stack: change is too _risky_ - far safer to keep them constrained, within the confines of the existing language, framework, and architecture. Which meant that to both me and the company, it wasn't worth the time it would take to do. But if nothing was done, either the stack would collapse under the strain of growth, or the increased burden of maintenance on even more patch-ridden code would drive the developers to sack it off and look elsewhere. Which again, wasn't an argument without an obvious rebuttal: "We can re-hire".


### Avoiding the argument altogether

I never had the above conversation. The only solution I could see was to eliminate the _time_ and _risk_ factors, as best I could.

That is, to be able to say "This will take minimal time to do, and benchmarks show it could provide X speed improvements at Y scale". Such data would be needed at pitch time to reduce the chance of being walked back to some lesser implementation. But in order to do this, I would need to build at least a proof of concept. I would also need to identify the main usage patterns of the existing stack, so routes fulfilling their function could be incorporated into the proof-of-concept, and used to benchmark against. My actual full-time job already took up more than my allocated working hours, and asking for time to be blocked out in order to work on the proof-of-concept ran the risk of a) a refusal of the concept as a whole before even beginning, due to lack of above data; and b) not being allocated **enough** time to see it through to the point where it could be proved to be better. Even though it represented a simpler solution, redesigning and rewriting a whole domain's backend was not going to be a quick task. And even with enough time, there was the very real risk that my confidence was misplaced, and the solution I arrived at would end up benchmarking worse.

Therefore, I'd have to do it _in secret_. Or at least, on my own time, and without mentioning it - not until it was proven. Again, I enjoy coding, so I'm no stranger to doing it in my spare time - it's a hobby after all. Pursuing it outside of work allows me to keep learning new things, and to maintain and develop skills in areas that aren't touched on during the day to day (for example, running my home Kubernetes cluster). I had been primarily a Go developer in my previous role doing exactly this sort of backend domain architecture, so this rewrite served as a useful proxy through which to maintain (and build on) that knowledge.

But this wasn't an odd-evening coding kind of task: this was an _every_-evening, many weekends situation. And it it wasn't merely work-adjacent, it _was work_. As such, I lost whatever work-life balance I had left, for a good few months. And that's no way to go about working. And it was self-inflicted!

But, it worked: I got a proof of concept together, tested it thoroughly, and used that to put together a formal pitch presentation. This covered the performance and risks of both the existing and proposed implementations, a description of the architecture, and a deployment strategy. And because the proof of concept was very fleshed out, it required little time to add any extra features required to go from concept to production - a couple of domain elaboration sessions determined the API schema most useful for the analysts and developers consuming the provided data. The pitch was accepted; and over 6 months or so, rolled out incrementally. And it proved it's worth: it served the frontend two orders of magnitude quicker at equal operational scale, and was accessible and understandable enough to be easily worked on or implemented by developers new to it.

Just because the strategy worked, however, does not mean it was advisable. Let's see how it might've gone differently.

### Summing up the lessons

The reason I think there is a discussion to be had around culture at all here, is that decisions made by employees are shaped by the environment in which they operate. Yes, each individual will act differently within those bounds - but the culture will ultimately provide limits on those choices. I chose to work on something out of my remit, and do it out-of-hours, primarily because of my character, granted; but it was also because of the learned behaviours propagated by the company culture. And it might have been a bit different if the following suggestions were more keenly welcomed:

**Have a culture of caring.** About the people; their experience; and quality of their code. If there was a more clearly felt intent to keep the development team happy, at least insofar as carrying out their work goes, then the person-focussed argument would have felt like a stronger line of reasoning - and I might have felt more able to argue for _the idea_, instead of for a built proof-of-concept. Likewise, if code quality was of a higher priority.

**Have a culture of failure.** As in: be more accepting of experiments, especially failed experiments. This comes from both a company level, and a personal level: I was afraid to tell anyone of the project until I had proved to myself it was performant, which further drove me to the decision to develop it in secret. Failing to realize any gains through investigating an inspiration is only remiss when said investigation was doomed to fail from the start, or via the approach decided upon. Otherwise, it should be encouraged for developers to consider improvements and attempt to implement them - and accepted if they turn out fruitless. For every few failed spikes, there'll be a success that'll bring tangible benefit to some corner of the codebase.

**Have a culture of rewriting things.** The second pass at a problem will often be better than the first, as it will be carried out with a much greater understanding of the problem space. Not that anyone should refactor for the sake of it; rather, identify bottlenecks and potential problem spots, and enable the people who understand them best to give those elements another go. (In fact, I lost a good month's worth of work when I accidentally deleted my entire first effort at the rewrite! But it was a blessing, as the from-scratch implementation that followed was much improved: more focussed, less sprawling).

Together, I think these principles could help to foster an environment where no one has to do what I did. And hopefully, they are things I can incorporate and encourage going forward in my career.

