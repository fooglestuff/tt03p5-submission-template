from intelhex import IntelHex
ih = IntelHex()
ih.loadhex('testpgm.hex')
pydict = ih.todict()

with open('testpgm.txt', 'w') as f:
	for i in range(0, 8192):
		if(i in pydict.keys()):
			f.write(format(pydict[i], 'x'))
			f.write(' ')
		else:
			f.write('00 ')
		if(((i + 1) & 15) == 0):
			f.write('\n')
