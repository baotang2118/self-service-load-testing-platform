# Sr. DevOps Engineer (Sep 2026) - Take-home Assignment

## Problem: Self-Service Ephemeral Load Testing Engine

**Time-box:** 7-day calendar window.

**AI tools:** you can use any AI coding assistant or agent (Copilot, Claude, Cursor, ChatGPT, etc.). 
Include an AI-USAGE.md, documenting: which tools you used, representative prompts and any 
agentic workflow or configuration you set up for this assignment, and how you validated what the 
AI produced before using it.

## Context

You are a Senior DevOps engineer at a mid-sized company with 50 microservices deployed on a 
major cloud. Product development teams write and own their services. 

Today, whenever a team wants to load-test their service, they file a ticket with the DevOps team. 
DevOps provisions an environment, deploys the service, stands up load-generator infrastructure, 
and hands over access. The developer then authors and runs the test, watches the metrics, and 
interprets the results. When they are done, they ask DevOps to tear the environment down. This 
ticket-driven loop slows delivery, consumes DevOps capacity on repetitive setup and teardown, 
and gets skipped when timelines get tight. 

Your job is to design and prototype a self-service load testing engine that development teams can 
use without filing tickets, while enforcing the guardrails and standards required from a 
DevOps/infrastructure perspective. 

## Goal

Provide a self-service load testing capability that lets product development teams load-test their 
microservices on demand, without needing to file tickets to DevOps for setup or teardown.

Two things to consider:
- Developer experience: a clear, low-friction flow that follows a sensible load-test procedure. You define what that flow and experience look like. 
- Platform guardrails and best practices: cost controls, environment isolation, safe defaults, enforced teardown, and any security controls appropriate to running in shared cloud infrastructure. You define what guardrails are enforced and how.

Justify and talk about these two aspects in your writeup.

## Scope you are expected to define yourself

- Which cloud (AWS or GCP).
- How the ephemeral environment is created (namespace-per-test, dedicated cluster, serverless, containers, VMs, or other).
- Which load generator
- IaC tool
- CI/CD tool
- How service dependencies (databases, other services) are handled (mocks, stubs, seeded data, real deps). 
- Cost, teardown, and safety guardrails.
- How results are surfaced back to the developer.

## Deliverables 

Submit a single repository GitHub link or zip) containing: 

1. Working prototype. 
    - Runnable end-to-end for at least one representative microservice. A trivial sample service you provide is fine. 
    - IaC modules for cloud resources, structured the way you would ship them for real reuse. 
    - A CI/CD pipeline. 
    - A demo video showing the working product. 
    - A README explaining how to run it locally or in the cloud. 
2. Written writeup (WRITEUP.md, 2-3 pages maximum). 
    - Context you assumed and why. 
    - Alternatives you considered for the major decisions (env provisioning, load 
    generator, IaC layout, developer interface). What you picked and why. 
    - Trade-offs you accepted (cost, complexity, blast radius, developer experience, 
    security). 
    - What you would build next if you had another week 
3. AI-USAGE.md (see AI tools note above).

## Notes

- Scope aggressively. A small end-to-end prototype beats a large half-built one. 
- We will not answer clarifying questions on this assignment. If something is unclear, assumptions are expected. Document them clearly, and use them for your rationales. 
- We care much more about your reasoning and structure than about a polished UI or a comprehensive feature set.