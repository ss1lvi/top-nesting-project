import markovify

# # Get raw text as string.
with open("./internet_archive_scifi_v3.txt") as f:
    text_a = f.read()

with open("./clickbait.txt") as f:
    text_b = f.read()



# Build the model.
# text_model = markovify.Text(text)
model_a = markovify.Text(text_a)
model_b = markovify.NewlineText(text_b)

model_combo = markovify.combine([ model_a, model_b ], [ 1, 1.5 ])

# Print five randomly-generated sentences
for i in range(5):
    print(model_combo.make_sentence())

# Print three randomly-generated sentences of no more than 280 characters
for i in range(3):
    print(model_combo.make_short_sentence(280))