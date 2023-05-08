import json

res = json.load(open("distribution_calculated.json"))

for pair in res:
    addr = pair['address']
    amt = pair['amount']
    print(f'if (address == {addr})'.format(), end='')
    print('{')
    print(f'        return {amt};'.format())
    print('}')