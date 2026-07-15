const fs = require("fs");
const path = require("path");
const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, BorderStyle, WidthType, PageBreak, AlignmentType, VerticalAlign } = require("docx");

const createCell = (text, bold = false, shading = null) => {
    return new TableCell({
        children: [new Paragraph({ children: [new TextRun({ text: String(text), bold: bold })] })],
        verticalAlign: VerticalAlign.CENTER,
        shading: shading ? { fill: shading } : undefined,
        margins: { top: 100, bottom: 100, left: 100, right: 100 }
    });
};

const createHeading = (text, level) => {
    return new Paragraph({
        text: text,
        heading: level,
        spacing: { before: 200, after: 100 }
    });
};

function generateSummary() {
    const rawResults = fs.readFileSync(path.join(__dirname, 'sources', 'backend', 'qa_results.json'), 'utf8');
    const results = JSON.parse(rawResults);

    const doc = new Document({
        creator: "QA Engineer",
        title: "ToyShop ERP - Test Execution Summary",
        sections: [
            {
                children: [
                    new Paragraph({
                        children: [new TextRun({ text: "Test Execution Summary", bold: true, size: 48 })],
                        alignment: AlignmentType.CENTER,
                        spacing: { after: 1000 }
                    }),
                    createHeading("Metrics", HeadingLevel.HEADING_1),
                    new Table({
                        width: { size: 100, type: WidthType.PERCENTAGE },
                        rows: [
                            new TableRow({ children: [createCell("Metric", true, "E0E0E0"), createCell("Value", true, "E0E0E0")] }),
                            new TableRow({ children: [createCell("Total Modules Analyzed"), createCell(results.modulesTested)] }),
                            new TableRow({ children: [createCell("Total Test Cases Executed"), createCell(results.totalTests)] }),
                            new TableRow({ children: [createCell("Passed"), createCell(results.passed)] }),
                            new TableRow({ children: [createCell("Failed"), createCell(results.failed)] }),
                            new TableRow({ children: [createCell("Pass Percentage"), createCell(`${Math.round((results.passed / results.totalTests) * 100)}%`)] })
                        ]
                    }),
                    new Paragraph({ text: "", spacing: { after: 1000 } }),
                    createHeading("Detailed Status", HeadingLevel.HEADING_1),
                    new Table({
                        width: { size: 100, type: WidthType.PERCENTAGE },
                        rows: [
                            new TableRow({ children: [createCell("Test Case ID", true, "E0E0E0"), createCell("Module", true, "E0E0E0"), createCell("Endpoint", true, "E0E0E0"), createCell("Status", true, "E0E0E0")] }),
                            ...results.tests.map(tc => {
                                return new TableRow({ children: [createCell(tc.id), createCell(tc.module), createCell(tc.endpoint), createCell(tc.status)] });
                            })
                        ]
                    })
                ]
            }
        ]
    });

    Packer.toBuffer(doc).then((buffer) => {
        fs.writeFileSync(path.join(__dirname, "ToyShopERP_Execution_Summary.docx"), buffer);
        console.log("ToyShopERP_Execution_Summary.docx generated successfully.");
    });
}

generateSummary();
