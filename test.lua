fk={}pcall(function()dofile'lua/freekill.lua'end)
a=Exppattern:Parse('slash,asd,df,^sd,sfff,^(xzc,afsd)|34,23|.|.|.|.|^(23~32)')
p(a.matchers)
c = { trueName = 'slash', number = 4, id = 155 }
p(a:match(c))
p(a:matchExp('^jink'))
print(a)
