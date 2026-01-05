from src.multi_intent import predict_multi_intent

def repl():
    print("Hybrid Transformer Home Automation (offline). Type 'exit' to quit.")
    while True:
        text = input("Enter command: ").strip()
        if text.lower() in ("exit", "quit"):
            break
        print(predict_multi_intent(text))

if __name__ == "__main__":
    repl()
