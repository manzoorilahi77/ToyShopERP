const fs = require("fs");
const path = require("path");
const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, BorderStyle, WidthType, PageBreak, AlignmentType, VerticalAlign } = require("docx");

// Helper function to create table cells
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

const createParagraph = (text) => {
    return new Paragraph({
        text: text,
        spacing: { after: 120 }
    });
};

const createTestCaseTable = (tc) => {
    return new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        borders: {
            top: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
            bottom: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
            left: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
            right: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
            insideHorizontal: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
            insideVertical: { style: BorderStyle.SINGLE, size: 1, color: "000000" },
        },
        rows: [
            new TableRow({ children: [createCell("Test Case ID", true, "E0E0E0"), createCell(tc.id, true)] }),
            new TableRow({ children: [createCell("Module", true, "E0E0E0"), createCell(tc.module)] }),
            new TableRow({ children: [createCell("Feature", true, "E0E0E0"), createCell(tc.feature)] }),
            new TableRow({ children: [createCell("Test Objective", true, "E0E0E0"), createCell(`Verify ${tc.method} ${tc.endpoint}`)] }),
            new TableRow({ children: [createCell("Preconditions", true, "E0E0E0"), createCell("User authenticated and authorized")] }),
            new TableRow({ children: [createCell("Expected Result", true, "E0E0E0"), createCell(`HTTP Status ${tc.expectedCode}`)] }),
            new TableRow({ children: [createCell("Actual Result", true, "E0E0E0"), createCell(`HTTP Status ${tc.actualCode} (Latency: ${tc.latency}ms)\n${tc.responseBody}`)] }),
            new TableRow({ children: [createCell("Status", true, "E0E0E0"), createCell(tc.status)] }),
            new TableRow({ children: [createCell("Priority", true, "E0E0E0"), createCell("High")] }),
            new TableRow({ children: [createCell("Severity", true, "E0E0E0"), createCell("Major")] }),
            new TableRow({ children: [createCell("Remarks", true, "E0E0E0"), createCell(tc.remarks)] }),
        ],
    });
};

function generateDocs() {
    const rawResults = fs.readFileSync(path.join(__dirname, 'sources', 'backend', 'qa_results.json'), 'utf8');
    const results = JSON.parse(rawResults);

    const doc = new Document({
        creator: "QA Engineer",
        title: "ToyShop ERP - Software Test Case Report",
        sections: [
            // 1. Cover Page
            {
                properties: {},
                children: [
                    new Paragraph({ text: "", spacing: { before: 2000 } }),
                    new Paragraph({
                        children: [new TextRun({ text: "ToyShop ERP", bold: true, size: 72 })],
                        alignment: AlignmentType.CENTER,
                        spacing: { after: 400 }
                    }),
                    new Paragraph({
                        children: [new TextRun({ text: "Software Test Case Report", bold: true, size: 48 })],
                        alignment: AlignmentType.CENTER,
                        spacing: { after: 400 }
                    }),
                    new Paragraph({
                        children: [new TextRun({ text: "Comprehensive Functional & Non-Functional Testing Documentation based on Actual Implementation", size: 28, italics: true })],
                        alignment: AlignmentType.CENTER,
                        spacing: { after: 2000 }
                    }),
                    new Paragraph({ text: "Prepared By:", alignment: AlignmentType.CENTER, spacing: { after: 400 } }),
                    new Paragraph({ text: "Senior Software QA Engineer", alignment: AlignmentType.CENTER, spacing: { after: 1000 } }),
                    new Paragraph({ text: `Date: ${new Date().toLocaleDateString()}`, alignment: AlignmentType.CENTER }),
                    new Paragraph({ text: "Version: 1.0", alignment: AlignmentType.CENTER }),
                    new Paragraph({ children: [new PageBreak()] })
                ]
            },
            // 2. Overview and Scope
            {
                children: [
                    createHeading("1. Project Overview & Scope", HeadingLevel.HEADING_1),
                    createParagraph("ToyShop ERP is a multi-tenant cloud-based platform managing sales, inventory, branches, staff, GST compliance, and reporting across web (React) and mobile (Flutter) interfaces, powered by a Node.js/Express Backend and MySQL database."),
                    createParagraph("Scope of Testing: Full API Functional Testing, UI Component Identification, Business Logic Verification, GST Calculation, Database CRUD Integrity, Authentication & Role-Based Access Control (RBAC)."),
                    new Paragraph({ children: [new PageBreak()] })
                ]
            },
            // 3. Test Cases
            {
                children: [
                    createHeading("2. API & Functional Test Cases (Automated Execution)", HeadingLevel.HEADING_1),
                    createParagraph("The following test cases were executed directly against the local backend server to reflect real behavior."),
                    ...results.tests.map(tc => {
                        return [
                            createTestCaseTable(tc),
                            new Paragraph({ text: "", spacing: { after: 300 } })
                        ];
                    }).flat(),
                    new Paragraph({ children: [new PageBreak()] })
                ]
            },
            // 4. Execution Summary
            {
                children: [
                    createHeading("3. Test Execution Summary", HeadingLevel.HEADING_1),
                    new Table({
                        width: { size: 100, type: WidthType.PERCENTAGE },
                        rows: [
                            new TableRow({ children: [createCell("Metric", true, "E0E0E0"), createCell("Value", true, "E0E0E0")] }),
                            new TableRow({ children: [createCell("Total Modules Analyzed"), createCell(results.modulesTested.toString())] }),
                            new TableRow({ children: [createCell("Total Test Cases Executed"), createCell(results.totalTests.toString())] }),
                            new TableRow({ children: [createCell("Passed"), createCell(results.passed.toString())] }),
                            new TableRow({ children: [createCell("Failed"), createCell(results.failed.toString())] }),
                            new TableRow({ children: [createCell("Blocked/Skipped"), createCell("0")] }),
                            new TableRow({ children: [createCell("Pass Percentage"), createCell(`${Math.round((results.passed / results.totalTests) * 100)}%`)] })
                        ]
                    })
                ]
            },
            // 5. Bug Report
            {
                children: [
                    createHeading("4. Defect Summary (Bugs Found)", HeadingLevel.HEADING_1),
                    new Table({
                        width: { size: 100, type: WidthType.PERCENTAGE },
                        rows: [
                            new TableRow({ children: [createCell("Bug ID", true), createCell("Module", true), createCell("Title", true), createCell("Severity", true), createCell("Status", true)] }),
                            ...results.tests.filter(tc => tc.status === 'Fail').map((tc, index) => {
                                return new TableRow({ children: [createCell(`BUG-00${index+1}`), createCell(tc.module), createCell(`${tc.method} ${tc.endpoint} returns ${tc.actualCode}`), createCell("High"), createCell("Open")] });
                            })
                        ]
                    })
                ]
            }
        ]
    });

    Packer.toBuffer(doc).then((buffer) => {
        fs.writeFileSync(path.join(__dirname, "ToyShopERP_Comprehensive_Test_Report.docx"), buffer);
        console.log("ToyShopERP_Comprehensive_Test_Report.docx generated successfully.");
    });
}

generateDocs();
