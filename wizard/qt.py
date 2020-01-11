from PyQt5 import QtWidgets
import sys
import core
import traceback


class MainWindow(QtWidgets.QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.layout = QtWidgets.QVBoxLayout()
        self.l1 = QtWidgets.QLabel("Ip:")
        self.layout.addWidget(self.l1)
        self.e1 = QtWidgets.QLineEdit()
        self.layout.addWidget(self.e1)
        self.l2 = QtWidgets.QLabel("Username:")
        self.layout.addWidget(self.l2)
        self.e2 = QtWidgets.QLineEdit()
        self.layout.addWidget(self.e2)
        self.l3 = QtWidgets.QLabel("Password:")
        self.layout.addWidget(self.l3)
        self.e3 = QtWidgets.QLineEdit()
        self.e3.setEchoMode(QtWidgets.QLineEdit.Password)
        self.layout.addWidget(self.e3)
        self.btn = QtWidgets.QPushButton("Submit")
        self.btn.clicked.connect(self.submit)
        self.layout.addWidget(self.btn)
        self.text = QtWidgets.QTextEdit()
        self.text.setReadOnly(True)
        self.layout.addWidget(self.text)
        self.setLayout(self.layout)

    def log(self, text):
        self.text.insertPlainText(text)

    def submit(self):
        try:
            core.connect(self.e1.text(), self.e2.text(), self.e3.text(), self.log, True)
        except Exception:
            self.log(traceback.format_exc())


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.setWindowTitle("Bitcart installer")
    window.showMaximized()
    sys.exit(app.exec_())
