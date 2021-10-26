import markovify

# # Get raw text as string.
# with open("./internet_archive_scifi_v3.txt") as f:
#     text_a = f.read()

with open("./internet_archive_scifi_v3.txt") as f:
    text_b = f.read()


# Build the model.
# text_model = markovify.Text(text)
# model_a = markovify.Text(text_a)
model_b = markovify.Text(text_b)

# model_combo = markovify.combine([ model_a, model_b ], [ 1, 1.5 ])

# Print five randomly-generated sentences
sents = []
for i in range(20):
    sents.append(model_b.make_sentence())
    # print(model_b.make_sentence())

print(" ".join(sents))
# print(sents)