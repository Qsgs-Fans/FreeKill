fk={}pcall(function()dofile'lua/freekill.lua'end)
a=Exppattern:Parse('slash')
p(a.matchers)
c = { trueName = 'slash', number = 4, id = 155 }
p(a:match(c))
p(a:matchExp('^jink'))
