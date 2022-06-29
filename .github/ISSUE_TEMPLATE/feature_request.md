---
name: Feature request
about: Suggest an idea for this project
title: "[FEATURE REQUEST]"
labels: ''
assignees: dreadpon

---

**Describe the problem you're trying to solve in your project**
*Give a brief description of what kind of project you're working on and what problem or limitation made you request a feature.*
Example:
"I'm working on a parkour game and I need my trees to collide with the player."


**Describe a feature you consider and how it will help you**
*Tell what your feature will do, how you would use it and how often.*
Example:
"Tree collision can be incorporated into existing LOD variants - that way it can even be freed dynamically or simplified. I would update all my tree `Plants` with physics bodies and use them throrought all my levels."


**Describe alternatives you've considered**
*A clear and concise description of any alternative solutions or features you've considered.*
Example:
"It's possible to iterate manually on all octree memebers, but tree collision seems like such a basic functionality, that it should be in the core plugin."


**Describe how you imagine it would work. With code, pseudo-code, diagram or a drawing**
*Give a breakdown from a technological perspective. Provide examples of similar functionality if possible.*
Example:
"Instead of referencing a mesh, LOD variants should be their own resource - housing both the mesh and a physics body. Whenever an instance is added or removed - update physics bodies as well."
