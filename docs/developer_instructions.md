# Architecture and Design
- Data-oriented design 
    - prioritise the effiecient processing of objects over their structure
- Entity-component and component-effect structures
    - Where possible effects, abilities, etc must be modular, prioritising many smaller scripts over single larger ones
- Test-driven development
    - Each feature must be modular and testable and expose parameters to be changed be humans for game feel

# Dev tips
- Always check the file structure first using `ls`.
- Always check there are no outstanding changes on git before editing with `git status`. If there are, stop and prompt the user.
- This is a British English project so no Americanisms in the code (eg. initialize over initialise).
- Always parameterise where possible and surface using `@export` and `@export_group`
- Ignore all other branches and treat this as the core branch with a single developer.
- UNDER NO CIRCUMSTANCES make changes to the other branches.

