import markovify
import datetime
from slugify import slugify

# # Get raw text as string.
# with open("./internet_archive_scifi_v3.txt") as f:
#     text_a = f.read()

with open("./clickbait.txt") as f:
    text_b = f.read()

model_b = markovify.NewlineText(text_b)

# model_combo = markovify.combine([ model_a, model_b ], [ 1, 1.5 ])
title = model_b.make_short_sentence(140)
print(title)

# ---
# title: "$TITLE"
# date: "$(date +%FT%TZ)"
# description: "test article number $i"
# categories: [paragraph]
# comments: true
# ---
#
# $TITLE

slug = slugify(title, max_length=16)

with open(f'{slug}/index.html', 'w') as f:
    f.write(f'---\n')
    f.write(f'title: {title}\n')
    f.write(f'date: {datetime.datetime.now().isoformat()}\n')
    f.write(f'description: {title}\n')
    f.write(f'categories: [paragraph]\n')
    f.write(f'comments: true\n')
    f.write(f'---\n')
    f.write(f'\n')
    f.write(f'{title}\n')