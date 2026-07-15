const fs = require("fs");
const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, BorderStyle, WidthType } = require("docx");

const doc = new Document({
    sections: [
        {
            properties: {},
            children: [
                new Paragraph({
                    text: "ToyShop ERP - Complete Test Case and Bug Report",
                    heading: HeadingLevel.TITLE,
                    alignment: "center",
                }),
                new Paragraph({
                    text: "Date: 15-July-2026",
                    alignment: "center",
                }),
                new Paragraph({ text: "", spacing: { after: 200 } }),

                new Paragraph({
                    text: "1. Executive Summary",
                    heading: HeadingLevel.HEADING_1,
                }),
                new Paragraph({
                    text: "This document contains a comprehensive test case report and a summary of recently resolved bugs for the ToyShop ERP Web Application. The application has been tested across all its user roles: SuperAdmin, Owner, and Staff, covering the frontend React application and backend Node.js APIs.",
                }),
                new Paragraph({ text: "", spacing: { after: 200 } }),

                new Paragraph({
                    text: "2. Test Cases",
                    heading: HeadingLevel.HEADING_1,
                }),
                
                // SuperAdmin Test Cases
                new Paragraph({ text: "2.1 Super Admin Module", heading: HeadingLevel.HEADING_2 }),
                new Paragraph({ text: "TC01: Verify SuperAdmin Login successfully authenticates valid credentials." }),
                new Paragraph({ text: "TC02: Verify Tenants Management page loads and displays all active stores." }),
                new Paragraph({ text: "TC03: Verify SuperAdmin can view Global Stock and Global Staff across all branches." }),
                new Paragraph({ text: "TC04: Verify Subscriptions page correctly reflects active tenant subscriptions." }),
                new Paragraph({ text: "TC05: Verify System Logs record login and critical system events accurately." }),
                new Paragraph({ text: "", spacing: { after: 100 } }),

                // Owner Test Cases
                new Paragraph({ text: "2.2 Owner Module", heading: HeadingLevel.HEADING_2 }),
                new Paragraph({ text: "TC06: Verify Owner Dashboard displays accurate total sales and stock alerts." }),
                new Paragraph({ text: "TC07: Verify Owner can create, edit, and delete branches in Branches Management." }),
                new Paragraph({ text: "TC08: Verify Owner can add new staff and assign branches in Staff Management." }),
                new Paragraph({ text: "TC09: Verify Products List loads correctly with accurate HSN Code and GST percentage." }),
                new Paragraph({ text: "TC10: Verify Stock Addition automatically generates SKU ID when configured." }),
                new Paragraph({ text: "TC11: Verify Reports page accurately aggregates sales and profit data." }),
                new Paragraph({ text: "TC12: Verify Excel Report Generation downloads a valid, properly formatted .xlsx file." }),
                new Paragraph({ text: "TC13: Verify GST Dashboard and GST Registrations handle tax logic perfectly." }),
                new Paragraph({ text: "", spacing: { after: 100 } }),

                // Staff Test Cases
                new Paragraph({ text: "2.3 Staff Module", heading: HeadingLevel.HEADING_2 }),
                new Paragraph({ text: "TC14: Verify Staff Login successfully authenticates valid credentials." }),
                new Paragraph({ text: "TC15: Verify New Sale correctly calculates totals, subtotals, and GST upon item modification." }),
                new Paragraph({ text: "TC16: Verify New Sale deducts stock correctly after completing a transaction." }),
                new Paragraph({ text: "TC17: Verify Sales History displays all past transactions for the logged-in staff." }),
                new Paragraph({ text: "TC18: Verify Product Catalog displays items with their current stock availability." }),
                new Paragraph({ text: "", spacing: { after: 200 } }),

                new Paragraph({
                    text: "3. Bug Report & Resolutions",
                    heading: HeadingLevel.HEADING_1,
                }),

                new Paragraph({ text: "Bug 01: Dashboard Sales Data Filtering Issue", heading: HeadingLevel.HEADING_3 }),
                new Paragraph({ text: "Status: Resolved. Description: Dashboard sales reports displayed zero values when filtering for 'yesterday'. Fixed date-based data retrieval logic in the backend controllers." }),

                new Paragraph({ text: "Bug 02: Staff Creation 400 Error", heading: HeadingLevel.HEADING_3 }),
                new Paragraph({ text: "Status: Resolved. Description: Encountered 400 Bad Request error during new staff creation due to missing payload validations." }),

                new Paragraph({ text: "Bug 03: Sales Calculation Logic Discrepancy", heading: HeadingLevel.HEADING_3 }),
                new Paragraph({ text: "Status: Resolved. Description: Modifying items during a sale caused incorrect total/subtotal. Corrected calculation logic in saleController.js." }),

                new Paragraph({ text: "Bug 04: Backend Connection Refused", heading: HeadingLevel.HEADING_3 }),
                new Paragraph({ text: "Status: Resolved. Description: Fixed backend database connection string and port binding issues." }),

                new Paragraph({ text: "Bug 05: Excel Report Generation Failure", heading: HeadingLevel.HEADING_3 }),
                new Paragraph({ text: "Status: Resolved. Description: Generated reports were corrupted. Handled correct aggregation and response headers for .xlsx files." }),
                new Paragraph({ text: "", spacing: { after: 200 } }),
                
                new Paragraph({
                    text: "4. Conclusion",
                    heading: HeadingLevel.HEADING_1,
                }),
                new Paragraph({
                    text: "The ToyShop ERP system has been extensively tested. Core flows including sales, stock management, tenant management, and GST reporting are fully functional. Recent critical bugs have been addressed, ensuring stability across both frontend and backend."
                }),
            ],
        },
    ],
});

Packer.toBuffer(doc).then((buffer) => {
    fs.writeFileSync("ToyShopERP_Test_Report.docx", buffer);
    console.log("Document created successfully");
});
