*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt and deletes screenshot
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.Browser.Selenium
Library             RPA.HTTP
Library             RPA.Tables
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.FileSystem
Library             RPA.Dialogs
Library             RPA.Robocorp.Vault


*** Variables ***
${RECEIPTS}     ${OUTPUT_DIR}${/}receipts
${BASEURL}      https://robotsparebinindustries.com


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Log secret welcome message
    # Remove old zip file
    Remove File    ${OUTPUT_DIR}${/}receipts.zip
    ${filename}=    Open dialog for order file
    Open the robot order website
    ${orders}=    Get orders    ${filename}
    # Log amount of orders to process
    ${count}=    Get Length    ${orders}
    Log    ${count}
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        # Try to process order for 10 times
        Wait Until Keyword Succeeds    10x    2s    Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
        #BREAK
    END
    Create a ZIP file of the receipts
    [Teardown]    Cleanup


*** Keywords ***
Open the robot order website
    Open Headless Chrome Browser    ${BASEURL}/#/robot-order

Get orders
    [Arguments]    ${file}
    # Download orders
    Download    ${BASEURL}/${file}    overwrite=True
    ${orders}=    Read table from CSV    orders.csv
    RETURN    ${orders}

Close the annoying modal
    Wait Until Element Is Visible    css:div.modal-dialog
    Click Button    Yep

Fill the form
    [Arguments]    ${order}
    Select From List By Value    head    ${order}[Head]
    Select Radio Button    body    ${order}[Body]
    Input Text    css:input[placeholder="Enter the part number for the legs"]    ${order}[Legs]
    Input Text    address    ${order}[Address]

Preview the robot
    Click Button    id:preview
    Wait Until Element Is Visible    xpath://div[@id="robot-preview-image"]/img[1]    2s

Submit the order
    Click Button    id:order
    Wait Until Element Is Visible    id:receipt    2s

Store the receipt as a PDF file
    [Arguments]    ${orderNo}
    ${receipt}=    Get Element Attribute    id:receipt    innerHTML
    Html To Pdf    ${receipt}    ${RECEIPTS}${/}order_${orderNo}.pdf
    RETURN    ${RECEIPTS}${/}order_${orderNo}.pdf

Take a screenshot of the robot
    [Arguments]    ${orderNo}
    Wait Until Element Is Visible    id:robot-preview-image
    Screenshot    id:robot-preview-image    ${OUTPUT_DIR}${/}robot_${orderNo}.png
    RETURN    ${OUTPUT_DIR}${/}robot_${orderNo}.png

Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    Open Pdf    ${pdf}
    ${list}=    Create List    ${screenshot}:align=center
    # Watermark is the only possible way to get small image on same page
    Add Watermark Image To Pdf    ${screenshot}    ${pdf}
    Close Pdf    ${pdf}
    Remove File    ${screenshot}

Go to order another robot
    Click Button    id:order-another

Create a ZIP file of the receipts
    Archive Folder With Zip    ${RECEIPTS}    ${OUTPUT_DIR}${/}receipts.zip

Cleanup
    Close Browser
    ${dir_not_exists}=    Does Directory Not Exist    ${RECEIPTS}
    Skip If    ${dir_not_exists}
    Empty Directory    ${RECEIPTS}
    Remove Directory    ${RECEIPTS}

Open dialog for order file
    Add text    Please enter order CSV filename e.g. orders.csv
    Add text input    filename    label="filename"
    ${response}=    Run dialog
    RETURN    ${response.filename}

Log secret welcome message
    ${secrets}=    Get Secret    robotsparebin
    Log    ${secrets}[welcome]
